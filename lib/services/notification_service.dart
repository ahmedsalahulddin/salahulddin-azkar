import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/adhkar_data.dart';
import '../data/quran_data.dart';
import '../l10n/strings.dart';
import 'app_locale.dart';
import 'custom_reminders.dart';
import 'notification_router.dart';
import 'daily_reminders.dart';
import 'dhikr_reminder.dart';
import 'prayer_alerts.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _morningId = 1;
  static const _eveningId = 2;

  /// Its own id, so trying it twice replaces rather than stacks.
  static const _testId = 900;
  static const _scheduledTestId = 901;
  static const _adhanTestId = 902;

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

  /// The adhan clips iOS can play with a notification. iOS plays only sounds
  /// inside the app's bundle or its Library/Sounds folder, and only the first
  /// 30 seconds, so a 29-second fading clip of each adhan (assets/sounds) is
  /// copied there once. Without it the iPhone played its default chime.
  static Future<void> _installIosSounds() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final lib = await getLibraryDirectory();
      final dir = Directory('${lib.path}/Sounds');
      if (!dir.existsSync()) dir.createSync(recursive: true);
      // Each on its own, the small one first: one that cannot be written
      // must not cost the others.
      for (final name in const ['silence', 'adhan_makkah', 'adhan_madinah']) {
        try {
          final data = await rootBundle.load('assets/sounds/$name.caf');
          final file = File('${dir.path}/$name.caf');
          if (file.existsSync() && file.lengthSync() == data.lengthInBytes) {
            continue;
          }
          await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
        } catch (_) {
          // That one plays the default sound instead.
        }
      }
    } catch (_) {
      // The default sound still plays.
    }
  }

  /// The iOS notification sound for an adhan resource, or null for the
  /// system default.
  static String? _iosSound(String? resource) =>
      resource == null ? null : '$resource.caf';

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;
    await _ensureZone();
    await _installIosSounds();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      // A tap on a reminder opens the surah or adhkar it is about.
      onDidReceiveNotificationResponse: (r) =>
          NotificationRouter.open(r.payload),
    );
    _initialized = true;
    // Launched by tapping a notification while the app was closed: the tap
    // is replayed once the first screen is up.
    try {
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        NotificationRouter.open(launch!.notificationResponse?.payload);
      }
    } catch (_) {
      // No launch details on this platform; the app simply opens.
    }
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
      // A real zone on the same clock as the phone. It has to be one the
      // platform knows by name too: Android schedules by the zone's name,
      // and a made-up one ("local") made every prayer alert fail to
      // schedule. Etc/GMT zones carry the sign the other way round.
      final offset = DateTime.now().timeZoneOffset;
      final ms = offset.inMilliseconds;
      final hours = offset.inHours;
      tz.Location? match;
      if (offset.inMinutes % 60 == 0 && hours.abs() <= 12) {
        final etc = hours == 0
            ? 'Etc/UTC'
            : 'Etc/GMT${hours > 0 ? '-' : '+'}${hours.abs()}';
        match = tz.timeZoneDatabase.locations[etc];
      }
      match ??= tz.timeZoneDatabase.locations.values
          .where((l) => l.currentTimeZone.offset == ms)
          .firstOrNull;
      if (match != null) tz.setLocalLocation(match);
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
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (android != null) return await android.areNotificationsEnabled();

      final ios = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
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
      final at = tz.TZDateTime(
        tz.local,
        soon.year,
        soon.month,
        soon.day,
        soon.hour,
        soon.minute,
        soon.second,
      );

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
          at,
          testDetails,
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } catch (_) {
        await _plugin.zonedSchedule(
          _scheduledTestId,
          'التنبيه المجدول وصل',
          'أُرسل قبل دقيقة بنفس طريقة تنبيهات الصلاة والأذكار.',
          at,
          testDetails,
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

  /// Sends an immediate notification on the prayer sound channel with the
  /// chosen adhan, so the reader can hear whether the adhan plays correctly
  /// without waiting for prayer time.
  ///
  /// Returns the exception's own text on failure rather than a plain bool —
  /// a silent catch here left readers reporting "it doesn't work" with
  /// nothing to diagnose from.
  static Future<String?> sendPrayerSoundTest() async {
    if (kIsWeb) return 'web';
    try {
      await init();
      final soundResource = PrayerAlerts.bundledResource;
      final channel =
          'salahulddin_prayer_sound_v5_${soundResource ?? 'default'}';
      await _plugin.show(
        _adhanTestId,
        'جرّبت صوت الأذان',
        'هكذا سيصلك التنبيه وقت الصلاة.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel,
            'مواقيت الصلاة — بالصوت',
            channelDescription: 'تنبيهات الصلاة',
            importance: reminderImportance,
            priority: reminderPriority,
            playSound: true,
            sound: soundResource != null
                ? RawResourceAndroidNotificationSound(soundResource)
                : null,
            visibility: NotificationVisibility.public,
          ),
          iOS: DarwinNotificationDetails(
            presentSound: true,
            sound: _iosSound(soundResource),
          ),
        ),
      );
      return null;
    } catch (e) {
      return e.toString();
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
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
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
  /// The v2 and v3 prayer sound channels are also removed here: if they were
  /// first created in a session where a non-bundled adhan was selected,
  /// Android locked them without a sound and they could never play the adhan.
  /// v4 channels are created fresh with the correct sound file.
  static Future<void> _dropQuietChannels() async {
    const gone = [
      'salahulddin_dhikr_reminder',
      'salahulddin_daily',
      'salahulddin_prayer_silent',
      'salahulddin_prayer_sound_v2_adhan_makkah',
      'salahulddin_prayer_sound_v2_adhan_madinah',
      'salahulddin_prayer_sound_v2_default',
      'salahulddin_prayer_sound_v3_adhan_makkah',
      'salahulddin_prayer_sound_v3_adhan_madinah',
      'salahulddin_prayer_sound_v3_default',
      // v4 channels may exist without a sound: until res/raw/keep.xml, the
      // adhan files were stripped from release builds.
      'salahulddin_prayer_sound_v4_adhan_makkah',
      'salahulddin_prayer_sound_v4_adhan_madinah',
      'salahulddin_prayer_sound_v4_default',
    ];
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
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
  /// Lays down the reader's own reminders (see CustomReminders): one weekly
  /// notification per chosen weekday and time. Rebuilt whole on every change
  /// — every pending id in the custom range is cancelled first, so a deleted
  /// reminder or a removed time leaves nothing behind.
  static Future<void> scheduleCustomReminders() async {
    try {
      if (kIsWeb) return;
      await _ensureZone();
      await _trimPrayersOnIos();
      try {
        for (final p in await _plugin.pendingNotificationRequests()) {
          if (p.id >= CustomReminder.firstNotificationId) {
            await _plugin.cancel(p.id);
          }
        }
      } catch (_) {
        // Could not list them; laying down below still overwrites by id.
      }

      final surahs = await QuranService.index();
      for (final r in CustomReminders.list.value) {
        if (!r.enabled || r.days.isEmpty || r.times.isEmpty) continue;
        final (title, body) = _customText(r, surahs);
        for (final day in r.days) {
          for (var slot = 0; slot < r.times.length; slot++) {
            final id = CustomReminder.notificationId(r.id, day, slot);
            final at = nextWeekly(
              tz.TZDateTime.now(tz.local),
              day,
              r.times[slot],
            );
            try {
              await _scheduleWeekly(id, title, body, at, r.payload);
            } catch (_) {
              // One slot failing must not stop the rest.
            }
          }
        }
      }
    } finally {
      _relayPrayersOnIos();
    }
  }

  /// The next [weekday] (1 = Monday) at [minutes] after midnight, strictly
  /// after [now].
  @visibleForTesting
  static tz.TZDateTime nextWeekly(tz.TZDateTime now, int weekday, int minutes) {
    var at = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day,
      minutes ~/ 60,
      minutes % 60,
    );
    while (at.weekday != weekday || !at.isAfter(now)) {
      at = at.add(const Duration(days: 1));
    }
    return at;
  }

  static (String, String) _customText(
    CustomReminder r,
    List<SurahInfo> surahs,
  ) {
    if (r.kind == ReminderKind.surah) {
      final info = surahs.where((s) => s.number == r.surah).firstOrNull;
      final name = info == null
          ? '${r.surah}'
          : (AppLocale.code == 'ar' ? info.name : info.nameEn);
      return (
        t('myrem.notifSurahTitle').replaceFirst('%s', name),
        t('myrem.notifSurahBody').replaceFirst('%s', name),
      );
    }
    final name = t('adhkar.cat.${r.adhkarId}');
    return (
      t('myrem.notifAdhkarTitle').replaceFirst('%s', name),
      t('myrem.notifAdhkarBody').replaceFirst('%s', name),
    );
  }

  static Future<void> _scheduleWeekly(
    int id,
    String title,
    String body,
    tz.TZDateTime at,
    String payload,
  ) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'salahulddin_my_reminders',
        'تذكيراتي',
        channelDescription: 'التذكيرات التي يضبطها القارئ بنفسه',
        importance: reminderImportance,
        priority: reminderPriority,
        visibility: NotificationVisibility.public,
      ),
      iOS: DarwinNotificationDetails(presentSound: true),
    );
    // Exact when allowed (the reader set a time and expects it), inexact
    // otherwise — the same fallback the prayer alerts use.
    for (final mode in [
      AndroidScheduleMode.alarmClock,
      AndroidScheduleMode.inexactAllowWhileIdle,
    ]) {
      try {
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          at,
          details,
          androidScheduleMode: mode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: payload,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
        return;
      } catch (_) {
        // Exact not permitted; try the next mode.
      }
    }
  }

  /// Whether alerts can be laid down for the exact minute. Without this,
  /// Android 13+ falls back to an inexact alarm that a locked, dozing phone
  /// may hold back for many minutes — so the adhan arrives late or not at
  /// prayer time at all. Always true off Android.
  static Future<bool> exactAlarmsAllowed() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.canScheduleExactNotifications() ??
          true;
    } catch (_) {
      return true;
    }
  }

  /// Opens Android's "Alarms & reminders" page for this app. Returns whether
  /// exact alarms are allowed afterwards.
  static Future<bool> requestExactAlarms() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestExactAlarmsPermission();
    } catch (_) {
      // The page could not open; the card stays up and can be tapped again.
    }
    return exactAlarmsAllowed();
  }

  /// Prayer alert ids: 1000 + slot × 100 + prayer × 10 + when, where the
  /// slot is the alert's calendar day modulo ten. A given prayer on a given
  /// day keeps its id however often the times are worked out again, so a
  /// reload can neither cut off an adhan as it sounds nor leave an older
  /// alarm waiting under a different number.
  static int _prayerId(int slot, AlertPrayer prayer, AlertWhen when) =>
      1000 + slot * 100 + prayer.index * 10 + when.index;

  static int _epochDay(DateTime d) =>
      DateTime.utc(d.year, d.month, d.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// Every prayer alert carries the moment it is for, so a pending one can
  /// be told apart: due now, or left over from times that have moved.
  static const _prayerPayload = 'prayer:';

  static DateTime? _payloadMoment(String? payload) {
    if (payload == null || !payload.startsWith(_prayerPayload)) return null;
    final ms = int.tryParse(payload.substring(_prayerPayload.length));
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Lays down the alerts for [times] (the day in [PrayerAlerts.firstDay]),
  /// [tomorrow] and the days in [PrayerAlerts.later], plus last night's Isha
  /// while it is still to come — a week on Android, and on iPhone as many
  /// days as fit beside the app's other reminders under its 64.
  static Future<void> schedulePrayerAlerts(
    Map<AlertPrayer, DateTime> times, [
    Map<AlertPrayer, DateTime> tomorrow = const {},
  ]) {
    if (kIsWeb) return Future.value();
    // One run at a time: launch, the card, the ticker and a setting can all
    // ask at once, and two runs interleaving could undo each other.
    return _prayerRun = _prayerRun
        .then((_) => _schedulePrayerAlerts(times, tomorrow))
        .catchError((_) {});
  }

  static Future<void> _prayerRun = Future.value();

  /// What was last laid under each prayer id (id → epoch ms), so a prayer
  /// that has already been announced is not announced again when a reload
  /// works its time out a minute differently.
  static const _laidKey = 'prayer_alerts_laid';

  /// Times that differ by less than this are the same prayer, recomputed.
  static const _sameAlert = Duration(minutes: 3);

  /// iPhone: the app's other pending reminders, counted from the settings
  /// rather than from what iOS kept (which is already cut at 64).
  static int _otherReminderCount() {
    var n = 0;
    try {
      if (DhikrReminder.enabled.value) n += DhikrReminder.slotMinutes().length;
    } catch (_) {
      n += 12;
    }
    if (DailyReminders.verseOn.value) n += 2;
    if (DailyReminders.morningOn.value) n += 1;
    if (DailyReminders.eveningOn.value) n += 1;
    for (final r in CustomReminders.list.value) {
      if (r.enabled) n += r.days.length * r.times.length;
    }
    return n;
  }

  /// iPhone keeps the 64 notifications set last, so after another kind of
  /// reminder is laid down the prayers are laid again on top of it.
  /// iPhone, before another kind of reminder is laid: lay the prayers again
  /// under the new, smaller budget first, so the total never goes over 64
  /// and iOS has nothing of ours to drop.
  static Future<void> _trimPrayersOnIos() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    if (PrayerAlerts.lastTimes.isEmpty) return;
    await schedulePrayerAlerts(PrayerAlerts.lastTimes, PrayerAlerts.tomorrow);
  }

  static void _relayPrayersOnIos() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    if (PrayerAlerts.lastTimes.isEmpty) return;
    schedulePrayerAlerts(PrayerAlerts.lastTimes, PrayerAlerts.tomorrow);
  }

  static Future<void> _schedulePrayerAlerts(
    Map<AlertPrayer, DateTime> times,
    Map<AlertPrayer, DateTime> tomorrow,
  ) async {
    await _ensureZone();
    SharedPreferences? prefs;
    final laid = <int, int>{};
    try {
      prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_laidKey);
      if (raw != null) {
        for (final e in (jsonDecode(raw) as Map).entries) {
          laid[int.parse(e.key as String)] = (e.value as num).toInt();
        }
      }
    } catch (_) {}
    Map<int, DateTime?>? pending;
    try {
      pending = {
        for (final r in await _plugin.pendingNotificationRequests())
          r.id: _payloadMoment(r.payload),
      };
    } catch (_) {
      // Unknown: the rules below then lean on cancelling only what is safe.
    }

    // The ids used before alerts covered a week (100–241).
    for (var day = 0; day < 2; day++) {
      for (final prayer in AlertPrayer.values) {
        for (final when in AlertWhen.values) {
          final old = 100 + day * 100 + prayer.index * 10 + when.index;
          if (pending != null && !pending.containsKey(old)) continue;
          try {
            await _plugin.cancel(old);
          } catch (_) {}
          pending?.remove(old);
        }
      }
    }

    final perDay = AlertPrayer.values
        .expand((p) => AlertWhen.values.map((w) => PrayerAlerts.modeFor(p, w)))
        .where((m) => !m.isOff)
        .length;
    final days = PrayerAlerts.daysAhead;

    final first = PrayerAlerts.firstDay ?? DateTime.now();
    final today = _epochDay(first);
    final byDay = <int, Map<AlertPrayer, DateTime>>{
      if (PrayerAlerts.lateIsha != null)
        today - 1: {AlertPrayer.isha: PrayerAlerts.lateIsha!},
      today: times,
      if (days > 1) today + 1: tomorrow,
      for (var i = 0; i < PrayerAlerts.later.length && i + 2 < days; i++)
        today + 2 + i: PrayerAlerts.later[i],
    };

    // iPhone keeps only the 64 most recently set notifications of an app,
    // so the prayers take what the other reminders leave: the soonest
    // alerts first, never fewer than the next few.
    Set<int>? allowed;
    if (defaultTargetPlatform == TargetPlatform.iOS && perDay > 0) {
      final limit = math.max(62 - _otherReminderCount(), 5);
      final now = DateTime.now();
      final ahead = <(int, DateTime)>[];
      for (final e in byDay.entries) {
        for (final prayer in AlertPrayer.values) {
          final at = e.value[prayer];
          if (at == null) continue;
          for (final when in AlertWhen.values) {
            if (PrayerAlerts.modeFor(prayer, when).isOff) continue;
            final moment = when == AlertWhen.before
                ? at.subtract(Duration(minutes: PrayerAlerts.lead.value))
                : at;
            if (moment.isAfter(now)) {
              ahead.add((_prayerId(e.key % 10, prayer, when), moment));
            }
          }
        }
      }
      ahead.sort((x, y) => x.$2.compareTo(y.$2));
      allowed = {for (final a in ahead.take(limit)) a.$1};
    }

    // Farthest first, so today's are the last set — iPhone keeps those.
    for (var day = today + 8; day >= today - 1; day--) {
      await _layDown(
        byDay[day] ?? const {},
        slot: day % 10,
        pending: pending,
        laid: laid,
        allowed: allowed,
      );
    }
    try {
      await prefs?.setString(
        _laidKey,
        jsonEncode({for (final e in laid.entries) '${e.key}': e.value}),
      );
    } catch (_) {}
  }

  static Future<void> _layDown(
    Map<AlertPrayer, DateTime> times, {
    required int slot,
    required Map<int, DateTime?>? pending,
    required Map<int, int> laid,
    Set<int>? allowed,
  }) async {
    final now = DateTime.now();
    for (final prayer in AlertPrayer.values) {
      final at = times[prayer];
      for (final when in AlertWhen.values) {
        final id = _prayerId(slot, prayer, when);
        final mode = PrayerAlerts.modeFor(prayer, when);
        final waiting = pending == null
            ? null
            : (pending.containsKey(id) ? pending[id] : null);
        final isPending = pending == null || pending.containsKey(id);

        Future<void> drop() async {
          try {
            await _plugin.cancel(id);
          } catch (_) {
            // Nothing to cancel, or the system would not; carry on.
          }
        }

        if (mode.isOff) {
          if (isPending) await drop();
          continue;
        }
        final overBudget =
            allowed != null &&
            at != null &&
            !allowed.contains(id) &&
            (when == AlertWhen.before
                    ? at.subtract(Duration(minutes: PrayerAlerts.lead.value))
                    : at)
                .isAfter(now);
        if (at == null || overBudget) {
          // Nothing wanted here. A pending alert that is already due is left
          // to arrive (an inexact alarm can run late); anything still ahead
          // is left over and goes.
          if (isPending && (waiting == null || waiting.isAfter(now))) {
            await drop();
          }
          continue;
        }

        final moment = when == AlertWhen.before
            ? at.subtract(Duration(minutes: PrayerAlerts.lead.value))
            : at;
        if (!moment.isAfter(now)) {
          // Due: it has fired or is sounding now — left alone, since the
          // card reloads the second a prayer comes in. Unless what waits
          // under this id is for a later moment (the times moved earlier,
          // say the Asr school changed): that one would ring at the old
          // time, so it goes.
          if (waiting != null &&
              waiting.difference(moment) > _sameAlert &&
              waiting.isAfter(now)) {
            await drop();
          }
          continue;
        }

        // Already announced: this id fired a moment ago for a time within a
        // few minutes of this one — the same prayer, worked out again from a
        // slightly different fix. Laying it again would sound it twice.
        final last = laid[id];
        if (last != null &&
            !(pending?.containsKey(id) ?? true) &&
            last <= now.millisecondsSinceEpoch &&
            (moment.millisecondsSinceEpoch - last).abs() <=
                _sameAlert.inMilliseconds) {
          continue;
        }

        // Each on its own. One alert the system will not take — a sound it
        // cannot find, a channel it refuses — must not cost the other nine.
        try {
          await _scheduleAt(
            id: id,
            title: AppLocale.isEn
                ? (when == AlertWhen.before
                      ? '${prayer.displayName} is approaching'
                      : 'It is now time for ${prayer.displayName}')
                : (when == AlertWhen.before
                      ? 'اقتربت صلاة ${prayer.displayName}'
                      : 'حان الآن وقت صلاة ${prayer.displayName}'),
            body: AppLocale.isEn
                ? (when == AlertWhen.before
                      ? '${PrayerAlerts.lead.value} minutes remaining'
                      : 'Establish the prayer in remembrance of Me')
                : (when == AlertWhen.before
                      ? 'بقيت ${PrayerAlerts.lead.value} دقيقة'
                      : 'أقم الصلاة لذكري'),
            at: moment,
            mode: mode,
            // The adhan belongs to the call to prayer, not to the warning
            // before it: a full adhan fifteen minutes early would send
            // people out.
            soundResource: when == AlertWhen.onTime
                ? PrayerAlerts.bundledResource
                : null,
          );
          laid[id] = moment.millisecondsSinceEpoch;
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
    // v5: old v2/v3/v4 channels are deleted at startup (_dropQuietChannels) so
    // that any created without a sound get recreated here with the adhan.
    final channel = mode.sound
        ? 'salahulddin_prayer_sound_v5_${soundResource ?? 'default'}'
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
      // Marks it as an alarm rather than a chat-style notification, so Do Not
      // Disturb's "alarms" exception and the lock screen treat it as one.
      category: AndroidNotificationCategory.alarm,
    );
    // iPhone only vibrates for a notification that plays a sound, so
    // "notification and vibration" plays a second of silence.
    final iosDetails = DarwinNotificationDetails(
      presentSound: mode.sound || mode.notify,
      sound: mode.sound ? _iosSound(soundResource) : _iosSound('silence'),
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    final tzAt = tz.TZDateTime.from(at, tz.local);

    // alarmClock uses AlarmManager.setAlarmClock(), which is exempt from Doze
    // and fires at the exact minute. On Android 13+ without SCHEDULE_EXACT_ALARM
    // permission it throws SecurityException; the fallback still schedules it
    // inexactly so the alert is never silently lost.
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzAt,
        details,
        payload: '$_prayerPayload${at.millisecondsSinceEpoch}',
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
      return;
    } catch (_) {
      // Exact alarms not permitted on this device/OS version; fall through.
    }
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzAt,
      details,
      payload: '$_prayerPayload${at.millisecondsSinceEpoch}',
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
    try {
      await _ensureZone();
      await _trimPrayersOnIos();
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
        var at = tz.TZDateTime(
          tz.local,
          now.year,
          now.month,
          now.day,
          minutes[i] ~/ 60,
          minutes[i] % 60,
        );
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
    } finally {
      _relayPrayersOnIos();
    }
  }

  /// The fixed-hour reminders: a verse with its meaning twice a day, and the
  /// morning and evening adhkar at the hour the reader chose.
  ///
  /// Rebuilt whole every time, because the only correct way to change a
  /// schedule is to lay it down again — patching it leaves yesterday's slots
  /// firing beside today's.
  static Future<void> scheduleDailyReminders() async {
    try {
      await _ensureZone();
      await _trimPrayersOnIos();
      for (final id in [400, 401, 410, 411]) {
        await _plugin.cancel(id);
      }

      if (DailyReminders.verseOn.value) {
        // Two different verses, so the second arrival is not the first repeated.
        await _daily(
          400,
          'آية وتفسيرها',
          await _verseLine(0),
          DailyReminders.verseFirst.value,
        );
        await _daily(
          401,
          'آية وتفسيرها',
          await _verseLine(1),
          DailyReminders.verseSecond.value,
        );
      }
      if (DailyReminders.morningOn.value) {
        await _daily(
          410,
          'أذكار الصباح',
          'حان وقت أذكار الصباح',
          DailyReminders.morningAt.value,
        );
      }
      if (DailyReminders.eveningOn.value) {
        await _daily(
          411,
          'أذكار المساء',
          'حان وقت أذكار المساء',
          DailyReminders.eveningAt.value,
        );
      }
    } finally {
      _relayPrayersOnIos();
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
    int id,
    String title,
    String body,
    DayTime at,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      at.hour,
      at.minute,
    );
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
