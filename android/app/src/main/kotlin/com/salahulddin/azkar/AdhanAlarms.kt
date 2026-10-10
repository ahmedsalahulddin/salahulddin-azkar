package com.salahulddin.azkar

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import org.json.JSONObject
import java.io.File

/**
 * The adhan as the phone's own alarm.
 *
 * A notification's sound is played by the system's one shared notification
 * player, so the next notification from any app cuts it off. Here the alarm
 * clock wakes [AdhanReceiver], which starts [AdhanService]: the service plays
 * the whole adhan itself on the alarm stream, with its own audio focus and a
 * Stop button, and nobody else's notification can interrupt it.
 */
object AdhanAlarms {
    private const val PREFS = "adhan_alarms"

    private fun fire(ctx: Context, id: Int, src: String, title: String, body: String, vibrate: Boolean) =
        PendingIntent.getBroadcast(
            ctx, id,
            Intent(ctx, AdhanReceiver::class.java).setAction("adhan.$id")
                .putExtra("id", id).putExtra("src", src).putExtra("title", title)
                .putExtra("body", body).putExtra("vibrate", vibrate),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    /** False when Android has not allowed exact alarms; the caller then falls back. */
    fun schedule(ctx: Context, id: Int, at: Long, src: String, title: String, body: String, vibrate: Boolean): Boolean {
        val am = ctx.getSystemService(AlarmManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) return false
        return try {
            val show = PendingIntent.getActivity(
                ctx, id, Intent(ctx, MainActivity::class.java),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            am.setAlarmClock(AlarmManager.AlarmClockInfo(at, show), fire(ctx, id, src, title, body, vibrate))
            val j = JSONObject().put("at", at).put("src", src).put("title", title)
                .put("body", body).put("vibrate", vibrate)
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(id.toString(), j.toString()).apply()
            true
        } catch (e: SecurityException) {
            false
        }
    }

    fun cancel(ctx: Context, id: Int) {
        val am = ctx.getSystemService(AlarmManager::class.java)
        am.cancel(fire(ctx, id, "", "", "", false))
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(id.toString()).apply()
    }

    fun forget(ctx: Context, id: Int) =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(id.toString()).apply()

    /** After a reboot Android has dropped every alarm; lay the ones still ahead again. */
    fun rescheduleAll(ctx: Context) {
        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        for ((key, value) in prefs.all) {
            val j = try { JSONObject(value as String) } catch (e: Exception) { prefs.edit().remove(key).apply(); continue }
            val at = j.getLong("at")
            if (at <= now) { prefs.edit().remove(key).apply(); continue }
            schedule(ctx, key.toInt(), at, j.getString("src"), j.getString("title"), j.getString("body"), j.getBoolean("vibrate"))
        }
    }

    fun start(ctx: Context, id: Int, src: String, title: String, body: String, vibrate: Boolean) {
        val i = Intent(ctx, AdhanService::class.java).putExtra("id", id).putExtra("src", src)
            .putExtra("title", title).putExtra("body", body).putExtra("vibrate", vibrate)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) ctx.startForegroundService(i) else ctx.startService(i)
    }
}

class AdhanReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        val id = intent.getIntExtra("id", 0)
        AdhanAlarms.forget(ctx, id)
        AdhanAlarms.start(
            ctx, id, intent.getStringExtra("src") ?: "", intent.getStringExtra("title") ?: "",
            intent.getStringExtra("body") ?: "", intent.getBooleanExtra("vibrate", true),
        )
    }
}

class AdhanBootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) = AdhanAlarms.rescheduleAll(ctx)
}

class AdhanService : Service() {
    private var player: MediaPlayer? = null
    private var focus: AudioFocusRequest? = null
    private var id = 0
    private var title = ""
    private var body = ""

    override fun onBind(intent: Intent?): IBinder? = null

    private fun notification(playing: Boolean, vibrate: Boolean): Notification {
        val nm = getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel("salahulddin_adhan_alarm_v1", "الأذان", NotificationManager.IMPORTANCE_HIGH)
            ch.setSound(null, null)
            ch.enableVibration(vibrate)
            ch.lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            nm.createNotificationChannel(ch)
        }
        val open = PendingIntent.getActivity(
            this, id, Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, "salahulddin_adhan_alarm_v1") else Notification.Builder(this)
        b.setSmallIcon(R.drawable.ic_stat_notify).setContentTitle(title).setContentText(body)
            .setContentIntent(open).setCategory(Notification.CATEGORY_ALARM)
            .setVisibility(Notification.VISIBILITY_PUBLIC).setAutoCancel(!playing).setOngoing(playing)
        if (playing) {
            val stop = PendingIntent.getService(
                this, id, Intent(this, AdhanService::class.java).setAction("STOP"),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            b.addAction(Notification.Action.Builder(null, getString(R.string.adhan_stop), stop).build())
        }
        return b.build()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == "STOP") { finish(); return START_NOT_STICKY }
        id = intent?.getIntExtra("id", 0) ?: 0
        title = intent?.getStringExtra("title") ?: ""
        body = intent?.getStringExtra("body") ?: ""
        val vibrate = intent?.getBooleanExtra("vibrate", true) ?: true
        val src = intent?.getStringExtra("src") ?: ""
        val n = notification(true, vibrate)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            startForeground(id, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK) else startForeground(id, n)
        play(src)
        return START_NOT_STICKY
    }

    private fun play(src: String) {
        // A phone set to silent or vibrate stays quiet, as it would for any notification.
        val audio = getSystemService(AudioManager::class.java)
        if (audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) { finish(); return }
        try {
            val attrs = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                focus = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN_TRANSIENT_EXCLUSIVE)
                    .setAudioAttributes(attrs).build()
                audio.requestAudioFocus(focus!!)
            }
            val p = MediaPlayer()
            p.setAudioAttributes(attrs)
            p.setWakeMode(this, PowerManager.PARTIAL_WAKE_LOCK)
            if (src.startsWith("raw:")) {
                val res = resources.getIdentifier(src.removePrefix("raw:"), "raw", packageName)
                resources.openRawResourceFd(res).use { p.setDataSource(it.fileDescriptor, it.startOffset, it.length) }
            } else {
                p.setDataSource(File(src.removePrefix("file:")).absolutePath)
            }
            p.setOnCompletionListener { finish() }
            p.setOnErrorListener { _, _, _ -> finish(); true }
            p.prepare()
            p.start()
            player = p
        } catch (e: Exception) {
            finish()
        }
    }

    private fun finish() {
        player?.let { try { it.stop() } catch (_: Exception) {}; it.release() }
        player = null
        val audio = getSystemService(AudioManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) focus?.let { audio.abandonAudioFocusRequest(it) }
        focus = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        // The alert stays in the shade after the adhan, as a normal notification.
        if (title.isNotEmpty()) getSystemService(NotificationManager::class.java).notify(id, notification(false, false))
        stopSelf()
    }

    override fun onDestroy() {
        player?.release()
        player = null
        super.onDestroy()
    }
}
