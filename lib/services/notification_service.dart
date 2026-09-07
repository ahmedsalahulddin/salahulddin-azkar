import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
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
  static const _scheduledTestId = 901;

  /// How loudly every channel the app schedules on is allowed to speak.
  ///
  /// Named once and used everywhere, because the value is the whole
  /// difference between a notification that appears on the screen and one
  /// that only ever reaches the shade — and because Android fixes it when the
  /// channel is created, so getting it wrong cannot be corrected later under
  /// the same id.
  static const reminderImportance = Importance.max;
  static const reminderPriority = Priority.high;

  /// Every channel a scheduled notification goes out on.
  @visibleForTesting
  static const channels = <String>[
    'salahulddin_dhikr_v2',
    'salahulddin_daily_v2',
    'salahulddin_prayer_silent_v2',
    'salahulddin_test',
  ];

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    await _ensureZone();

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

  /// The clock, and only the clock.
  ///
  /// Every scheduler needs this before it writes a time, but none of them
  /// needs the notification plugin itself — and reaching for it is not free:
  /// initialize() waits on a platform channel, which inside a widget test
  /// waits on a message loop the test clock never turns. Full init() here
  /// hung the suite for ten minutes rather than failing.
  static bool _zoneKnown = false;

  static Future<void> _ensureZone() async {
    if (kIsWeb || _zoneKnown) return;
    tz.initializeTimeZones();
    await syncTimeZone();
    _zoneKnown = true;
  }

  /// Teaches the schedule which clock the reader is actually reading.
  ///
  /// initializeTimeZones() loads the world's zones; it does not say which one
  /// we are in, and until told, tz.local is UTC. Nothing warns you: every call
  /// succeeds, every notification is scheduled, and pendingNotificationRequests
  /// counts them all. But a reminder built from an hour and a minute — "3:55"
  /// — is then built at 3:55 UTC, and a reader in the Kingdom is handed it at
  /// 6:55. The app says one time and the phone does another, which reads
  /// exactly like reminders that never arrive.
  ///
  /// The named zone is asked for first, because only a name carries the
  /// summer-time rules. If the platform will not give one, a fixed offset from
  /// the device clock is still right today and every day the app is opened,
  /// and is in every case better than standing in Greenwich.
  static Future<void> syncTimeZone() async {
    try {
      final name = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(name));
      return;
    } catch (_) {
      // No name, or a name this build of the database does not carry.
    }
    try {
      final offset = DateTime.now().timeZoneOffset;
      tz.setLocalLocation(tz.Location(
        'local',
        const [tz.minTime],
        const [0],
        [
          tz.TimeZone(offset.inMilliseconds,
              isDst: false, abbreviation: DateTime.now().timeZoneName),
        ],
      ));
    } catch (_) {
      // UTC, and the times will be wrong — but nothing here may throw and
      // take the whole notification system down with it.
    }
  }

  /// The clock the reminders are being written against, for the reader to
  /// see. A wrong zone is otherwise completely silent: it schedules, it
  /// counts, and it delivers — at the wrong hour.
  static String get zoneName {
    try {
      final offset = tz.TZDateTime.now(tz.local).timeZoneOffset;
      final sign = offset.isNegative ? '-' : '+';
      final hours = offset.abs().inHours;
      final minutes = offset.abs().inMinutes % 60;
      final clock = minutes == 0
          ? '$sign$hours'
          : '$sign$hours:${minutes.toString().padLeft(2, '0')}';
      return '${tz.local.name} (UTC$clock)';
    } catch (_) {
      return '';
    }
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
            importance: reminderImportance,
            priority: reminderPriority,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(),
        ),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  /// One notification, a minute from now, down the exact path the reminders
  /// take.
  ///
  /// The immediate test proves the permission and nothing else: it calls
  /// show(), which hands the notification straight to the system, while every
  /// real reminder goes through zonedSchedule() — a different mechanism, an
  /// alarm the system holds and may defer, drop while dozing, or refuse to a
  /// battery-optimised app. A test that skips all of that answers a question
  /// nobody asked.
  ///
  /// This one takes the reminders' own road: their channel, their schedule
  /// mode, one minute out. If it arrives, scheduling and delivery both work
  /// and any remaining fault is in the settings. If it does not, while the
  /// immediate one does, the phone is holding the alarm back — and that is
  /// the phone's battery settings, not the app's.
  ///
  /// And it is built the way a reminder is built — from an hour and a minute
  /// on the reader's clock, not from "now plus a duration". The difference
  /// looks like nothing and is the whole point: an offset is right in any
  /// timezone, including the wrong one, so a test written that way passed
  /// happily while every real reminder was hours out. This one is wrong
  /// exactly when the reminders are wrong.
  /// Empty when the alarm was accepted, and otherwise why it was not.
  ///
  /// It said only "تعذر" before, which is the least useful thing a failure can
  /// say: it cost a round trip through a build, a deploy and the reader's own
  /// phone to learn nothing but that something went wrong. The reason was
  /// sitting in a caught exception the whole time.
  static String lastScheduleError = '';

  static Future<bool> sendScheduledTest() async {
    if (kIsWeb) return false;
    lastScheduleError = '';
    try {
      await init();
      final soon = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
      final at = tz.TZDateTime(tz.local, soon.year, soon.month, soon.day,
          soon.hour, soon.minute, soon.second);

      const testDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'salahulddin_dhikr_v2',
          'تذكير بالذكر',
          channelDescription: 'ذكر قصير يصلك خلال اليوم',
          importance: reminderImportance,
          priority: reminderPriority,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(),
      );
      // Mirror the prayer-alert path: alarmClock first, inexact as fallback.
      try {
        await _plugin.zonedSchedule(
          _scheduledTestId,
          'التنبيه المجدول وصل',
          'أُرسل قبل دقيقة بنفس طريقة تنبيهات الصلاة والأذكار.',
          at, testDetails,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        await _plugin.zonedSchedule(
          _scheduledTestId,
          'التنبيه المجدول وصل',
          'أُرسل قبل دقيقة بنفس طريقة تنبيهات الصلاة والأذكار.',
          at, testDetails,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
      return true;
    } catch (e) {
      lastScheduleError = e.toString();
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

  /// Asks for the permission, and never throws for asking.
  ///
  /// Startup lays the plugin down inside a catch-all, which is right — a
  /// notification system that will not start must not stop the app opening.
  /// But it leaves a state where the plugin was never initialised, and this
  /// method reached straight into it: the three buttons on the settings card
  /// that call it would then throw where they were pressed, with nothing to
  /// catch them. Every other entry point here already guards itself; this one
  /// was the exception.
  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (_) {
      // Refused, or the plugin never started. Either way the reader is told
      // by the card above, which reads the permission rather than assuming.
    }
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
    await _dropQuietChannels();
  }

  /// Removes the channels that could never appear on screen.
  ///
  /// They were created at default importance, which Android reads as "put it
  /// in the shade and say nothing" — no banner, nothing on the lock screen.
  /// A channel's importance is fixed when it is made and an app may only
  /// lower it, so the replacements carry new ids and these are deleted rather
  /// than left sitting in the phone's settings under the same names.
  ///
  /// The v2 prayer sound channels are also removed here: if they were first
  /// created in a session where sound was off, Android locked them without a
  /// sound and they could never play the adhan. v3 channels are created fresh
  /// with the correct sound file.
  static Future<void> _dropQuietChannels() async {
    const gone = [
      'salahulddin_dhikr_reminder',
      'salahulddin_daily',
      'salahulddin_prayer_silent',
      'salahulddin_prayer_sound_v2_adhan_makkah',
      'salahulddin_prayer_sound_v2_adhan_madinah',
      'salahulddin_prayer_sound_v2_default',
    ];
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) return;
      for (final id in gone) {
        await android.deleteNotificationChannel(id);
      }
    } catch (_) {
      // An old channel left behind is untidy, never harmful.
    }
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
    await _ensureZone();
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
    //
    // v3: old v2 channels are deleted at startup (_dropQuietChannels) so that
    // any that were created without a sound get recreated here with the adhan.
    final channel = mode.sound
        ? 'salahulddin_prayer_sound_v3_${soundResource ?? 'default'}'
        : 'salahulddin_prayer_silent_v2';

    final androidDetails = AndroidNotificationDetails(
      channel,
      mode.sound ? 'مواقيت الصلاة — بالصوت' : 'مواقيت الصلاة — إشعار',
      channelDescription: 'تنبيهات الصلاة',
      importance: reminderImportance,
      priority: reminderPriority,
      playSound: mode.sound,
      enableVibration: mode.notify,
      sound: mode.sound && soundResource != null
          ? RawResourceAndroidNotificationSound(soundResource)
          : null,
      visibility: NotificationVisibility.public,
    );
    final iosDetails = DarwinNotificationDetails(presentSound: mode.sound);
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);
    final tzAt = tz.TZDateTime.from(at, tz.local);

    // alarmClock uses AlarmManager.setAlarmClock(), which is exempt from Doze
    // and fires at the exact minute. On Android 13+ without SCHEDULE_EXACT_ALARM
    // permission it throws SecurityException; the fallback still schedules it
    // inexactly so the alert is never silently lost.
    try {
      await _plugin.zonedSchedule(
        id, title, body, tzAt, details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return;
    } catch (_) {
      // Exact alarms not permitted on this device/OS version; fall through.
    }
    await _plugin.zonedSchedule(
      id, title, body, tzAt, details,
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
    await _ensureZone();
    // Clear the whole block first: the count can shrink, and yesterday's
    // extra slots would otherwise keep firing forever.
    for (var i = 0; i < 24; i++) {
      await _plugin.cancel(300 + i);
    }
    if (!enabled || pool.isEmpty) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        // v2, and it has to be: Android fixes a channel's importance when it
        // is created and an app may only ever lower it. The first id was made
        // at default importance, which puts a notification in the shade but
        // never on the screen — so these arrived and were never seen. Raising
        // the value alone would have changed nothing on a phone that already
        // had the app; only a new channel is created afresh.
        'salahulddin_dhikr_v2',
        'تذكير بالذكر',
        channelDescription: 'ذكر قصير يصلك خلال اليوم',
        importance: reminderImportance,
        priority: reminderPriority,
        visibility: NotificationVisibility.public,
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
    await _ensureZone();
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
          'salahulddin_daily_v2',
          'تذكيرات يومية',
          channelDescription: 'آية اليوم وأذكار الصباح والمساء',
          importance: reminderImportance,
          priority: reminderPriority,
          visibility: NotificationVisibility.public,
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
