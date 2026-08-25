import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/adhkar_data.dart';
import '../data/quran_data.dart';
import 'daily_reminders.dart';
import 'prayer_alerts.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _morningId = 1;
  static const _eveningId = 2;

  /// Its own id, so trying it twice replaces rather than stacks.
  static const _testId = 900;

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _initialized = true;
  }

  /// Whether the phone will actually show anything.
  ///
  /// Every switch in the settings can be on and every reminder scheduled, and
  /// still nothing arrives — because the reader said no to the permission
  /// once, or Android put the app to sleep. The app used to have no way to
  /// know that, and no way to tell them. Null means the platform would not
  /// say, which is treated as "probably yes" rather than alarming anyone.
  static Future<bool?> allowed() async {
    if (kIsWeb) return false;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) return android.areNotificationsEnabled();

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted = await ios.requestPermissions(alert: true);
        return granted;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// One notification, now.
  ///
  /// The reminders are the only part of the app whose working cannot be seen
  /// by looking: a prayer alert set for tomorrow's Fajr proves nothing today.
  /// This turns "did I set it up right?" into a question the reader can answer
  /// in a second, and separates a permission the phone is refusing from a
  /// schedule that simply has not come round yet.
  static Future<bool> sendTest() async {
    if (kIsWeb) return false;
    try {
      await init();
      await _plugin.show(
        _testId,
        'التنبيهات تعمل',
        'هكذا سيصلك الذكر والتذكير بمواقيت الصلاة.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'salahulddin_test',
            'تجربة التنبيهات',
            channelDescription: 'إشعار واحد للتأكد من وصول التنبيهات',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// How many notifications the system is actually holding for this app.
  ///
  /// The ground truth, and the one thing the app could not see. Every switch
  /// can be on, the permission granted, and still nothing arrives — because
  /// the schedule was never written. Laying it down is deliberately non-fatal
  /// so a failure cannot lose the reader's setting, which also means a
  /// failure leaves no trace. This is the trace: zero here says the alarms
  /// were never set, and any other number says they were and the question is
  /// delivery instead.
  static Future<int?> pending() async {
    if (kIsWeb) return null;
    try {
      final list = await _plugin.pendingNotificationRequests();
      return list.length;
    } catch (_) {
      return null;
    }
  }

  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Cancels the adhkar reminders that older versions laid down at a fixed
  /// six and five o'clock.
  ///
  /// The reader now chooses the hour, and those reminders are ids 410 and 411.
  /// Deleting the old code is not enough on a phone that already had them on:
  /// the schedule lives in Android, not in the app, so it would keep arriving
  /// beside the new one — which is exactly the doubling that was reported.
  static Future<void> clearLegacyAdhkarAlerts() async {
    if (kIsWeb) return;
    await _plugin.cancel(_morningId);
    await _plugin.cancel(_eveningId);
  }

  /// Lays down the prayer alerts from the reader's settings.
  ///
  /// Called after every prayer-times load, because the times move each day and
  /// a schedule laid down once would drift. Ids are derived from the prayer,
  /// the moment and the day, so rescheduling replaces rather than piles up.
  ///
  /// Two days, not one. A prayer time cannot simply repeat daily — it moves
  /// by a minute or two each morning — so each alert is set for its own
  /// moment, and the app re-lays them whenever it is opened. That left a gap:
  /// a reader who did not open the app for a day had nothing waiting for
  /// them the next. Tomorrow's are set too, so the alerts survive a day of
  /// not opening it.
  static Future<void> schedulePrayerAlerts(
    Map<AlertPrayer, DateTime> times, [
    Map<AlertPrayer, DateTime> tomorrow = const {},
  ]) async {
    await _layDown(times, dayOffset: 0);
    await _layDown(tomorrow, dayOffset: 1);
  }

  static Future<void> _layDown(
    Map<AlertPrayer, DateTime> times, {
    required int dayOffset,
  }) async {
    for (final prayer in AlertPrayer.values) {
      final at = times[prayer];
      for (final when in AlertWhen.values) {
        final id = 100 + dayOffset * 100 + prayer.index * 10 + when.index;
        try {
          await _plugin.cancel(id);
        } catch (_) {
          // Nothing to cancel, or the system would not; either way carry on.
        }

        final mode = PrayerAlerts.modeFor(prayer, when);
        if (mode.isOff || at == null) continue;

        final moment = when == AlertWhen.before
            ? at.subtract(Duration(minutes: PrayerAlerts.lead.value))
            : at;
        if (moment.isBefore(DateTime.now())) continue;

        // Each on its own. One alert the system will not take — a sound it
        // cannot find, a channel it refuses — must not cost the other nine.
        try {
          await _scheduleAt(
            id: id,
            title: when == AlertWhen.before
                ? 'اقتربت صلاة ${prayer.name}'
                : 'حان الآن وقت صلاة ${prayer.name}',
            body: when == AlertWhen.before
                ? 'بقيت ${PrayerAlerts.lead.value} دقيقة'
                : 'أقم الصلاة لذكري',
            at: moment,
            mode: mode,
            // The adhan belongs to the call to prayer, not to the warning
            // before it: a full adhan fifteen minutes early would send
            // people out.
            soundResource: when == AlertWhen.onTime
                ? PrayerAlerts.bundledResource
                : null,
          );
        } catch (_) {
          // Rebuilt at the next launch and at the next prayer-times load.
        }
      }
    }
  }

  static Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required AlertMode mode,
    String? soundResource,
  }) async {
    // Android fixes sound and vibration to the channel, not the notification,
    // so one channel could never be silent for one prayer and audible for the
    // next — nor play a different adhan after the reader changes it. The
    // channel id therefore carries both the mode and the chosen sound, and a
    // new combination simply creates a new channel.
    final channel = mode.sound
        ? 'salahulddin_prayer_sound_${soundResource ?? 'default'}'
        : 'salahulddin_prayer_silent';

    final androidDetails = AndroidNotificationDetails(
      channel,
      mode.sound ? 'مواقيت الصلاة — بالصوت' : 'مواقيت الصلاة — إشعار',
      channelDescription: 'تنبيهات الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      playSound: mode.sound,
      enableVibration: mode.notify,
      sound: mode.sound && soundResource != null
          ? RawResourceAndroidNotificationSound(soundResource)
          : null,
    );
    final iosDetails = DarwinNotificationDetails(presentSound: mode.sound);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(at, tz.local),
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Lays down the day's dhikr reminders, one per slot, each carrying a
  /// different dhikr so the rotation is visible rather than a single line
  /// repeating until it stops being read.
  static Future<void> scheduleDhikrReminders({
    required bool enabled,
    required List<int> minutes,
    required List<Dhikr> pool,
  }) async {
    // Clear the whole block first: the count can shrink, and yesterday's
    // extra slots would otherwise keep firing forever.
    for (var i = 0; i < 24; i++) {
      await _plugin.cancel(300 + i);
    }
    if (!enabled || pool.isEmpty) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'salahulddin_dhikr_reminder',
        'تذكير بالذكر',
        channelDescription: 'ذكر قصير يصلك خلال اليوم',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    for (var i = 0; i < minutes.length && i < 24; i++) {
      final dhikr = pool[i % pool.length];
      final now = tz.TZDateTime.now(tz.local);
      var at = tz.TZDateTime(tz.local, now.year, now.month, now.day,
          minutes[i] ~/ 60, minutes[i] % 60);
      if (at.isBefore(now)) at = at.add(const Duration(days: 1));

      await _plugin.zonedSchedule(
        300 + i,
        'ذكر',
        dhikr.text,
        at,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  /// The fixed-hour reminders: a verse with its meaning twice a day, and the
  /// morning and evening adhkar at the hour the reader chose.
  ///
  /// Rebuilt whole every time, because the only correct way to change a
  /// schedule is to lay it down again — patching it leaves yesterday's slots
  /// firing beside today's.
  static Future<void> scheduleDailyReminders() async {
    for (final id in [400, 401, 410, 411]) {
      await _plugin.cancel(id);
    }

    if (DailyReminders.verseOn.value) {
      // Two different verses, so the second arrival is not the first repeated.
      await _daily(400, 'آية وتفسيرها', await _verseLine(0),
          DailyReminders.verseFirst.value);
      await _daily(401, 'آية وتفسيرها', await _verseLine(1),
          DailyReminders.verseSecond.value);
    }
    if (DailyReminders.morningOn.value) {
      await _daily(410, 'أذكار الصباح', 'حان وقت أذكار الصباح',
          DailyReminders.morningAt.value);
    }
    if (DailyReminders.eveningOn.value) {
      await _daily(411, 'أذكار المساء', 'حان وقت أذكار المساء',
          DailyReminders.eveningAt.value);
    }
  }

  /// A verse and where it is from, read out of the bundled Mushaf rather than
  /// written here — the same rule the rest of the app follows.
  static Future<String> _verseLine(int offset) async {
    const picks = [(13, 28), (2, 152), (94, 5), (33, 41)];
    try {
      final (surahNumber, ayahNumber) =
          picks[(DateTime.now().day + offset) % picks.length];
      final index = await QuranService.index();
      final surah = await QuranService.surah(surahNumber);
      final ayah = surah.ayahs.firstWhere((a) => a.number == ayahNumber);
      final name = index.firstWhere((s) => s.number == surahNumber).name;
      return '${ayah.text}\n[$name: ${QuranService.toArabicDigits(ayahNumber)}]';
    } catch (_) {
      return 'افتح التطبيق لقراءة آية اليوم';
    }
  }

  static Future<void> _daily(
      int id, String title, String body, DayTime at) async {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, at.hour, at.minute);
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'salahulddin_daily',
          'تذكيرات يومية',
          channelDescription: 'آية اليوم وأذكار الصباح والمساء',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
