package com.salahulddin.azkar

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.provider.MediaStore
import androidx.core.content.FileProvider
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // The flutter_local_notifications plugin serialises scheduled
        // notifications to SharedPreferences. When the plugin is updated the
        // stored JSON may be missing a field the new deserialiser requires
        // ("Missing type parameter"), and every zonedSchedule() call then
        // fails because it loads that list before appending.
        //
        // We remove the stale entry once — before Flutter initialises — so
        // the plugin finds a clean slate. A null value causes the plugin to
        // return an empty list without parsing, which is exactly what we need.
        // The reminders are rebuilt immediately by main() after init().
        clearCorruptScheduledNotifications()
        super.onCreate(savedInstanceState)
    }

    // A downloaded adhan as a notification sound. The system, not the app,
    // plays a channel's sound, and it cannot open a file inside the app's
    // storage. Android 10+: the adhan is copied into the shared
    // Notifications folder (MediaStore — no permission needed for the app's
    // own entries), a link the system can always read, even after a reboot
    // when the alarms are re-laid without the app. Older Android: a
    // FileProvider link with read permission granted to the system, renewed
    // on every launch.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "salahulddin/adhan_sound")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "uriFor" -> result.success(uriFor(File(call.arguments as String)).toString())
                        "forget" -> {
                            forget(call.arguments as String)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("adhan_sound", e.message, null)
                }
            }
    }

    private val adhanFolder = Environment.DIRECTORY_NOTIFICATIONS + "/Salahulddin"

    private fun ownEntry(name: String): Uri? {
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        contentResolver.query(
            collection,
            arrayOf(MediaStore.Audio.Media._ID, MediaStore.Audio.Media.SIZE),
            "${MediaStore.Audio.Media.DISPLAY_NAME}=? AND ${MediaStore.Audio.Media.RELATIVE_PATH}=?",
            arrayOf(name, "$adhanFolder/"),
            null,
        )?.use { c ->
            if (c.moveToFirst() && c.getLong(1) > 0) return ContentUris.withAppendedId(collection, c.getLong(0))
        }
        return null
    }

    private fun uriFor(file: File): Uri {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            val uri = FileProvider.getUriForFile(this, "$packageName.adhanfiles", file)
            for (pkg in listOf("com.android.systemui", "android")) {
                grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            return uri
        }
        ownEntry(file.name)?.let { return it }
        val values = ContentValues().apply {
            put(MediaStore.Audio.Media.DISPLAY_NAME, file.name)
            put(MediaStore.Audio.Media.MIME_TYPE, "audio/mp4")
            put(MediaStore.Audio.Media.RELATIVE_PATH, adhanFolder)
            put(MediaStore.Audio.Media.IS_NOTIFICATION, 1)
            put(MediaStore.Audio.Media.IS_PENDING, 1)
        }
        val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = contentResolver.insert(collection, values) ?: throw IllegalStateException("insert")
        try {
            contentResolver.openOutputStream(uri)!!.use { out -> file.inputStream().use { it.copyTo(out) } }
            contentResolver.update(uri, ContentValues().apply { put(MediaStore.Audio.Media.IS_PENDING, 0) }, null, null)
        } catch (e: Exception) {
            contentResolver.delete(uri, null, null)
            throw e
        }
        return uri
    }

    private fun forget(name: String) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        ownEntry(name)?.let { contentResolver.delete(it, null, null) }
    }

    private fun clearCorruptScheduledNotifications() {
        val migrationPrefs = getSharedPreferences("azkar_migration", Context.MODE_PRIVATE)
        if (migrationPrefs.getBoolean("flln_v18_cleared", false)) return

        getSharedPreferences("scheduled_notifications", Context.MODE_PRIVATE)
            .edit()
            .remove("scheduled_notifications")
            .apply()

        migrationPrefs.edit().putBoolean("flln_v18_cleared", true).apply()
    }
}
