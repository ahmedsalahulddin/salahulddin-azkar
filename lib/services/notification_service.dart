import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../data/adhkar_data.dart';
import 'prayer_alerts.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _morningId = 1;
  static const _eveningId = 2;

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

  static Future<void> requestPermission() async {
    if (kIsWeb) return;
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> scheduleMorning(bool enable) async {
    if (kIsWeb) return;
    if (!enable) {
      await _plugin.cancel(_morningId);
      return;
    }
    await _scheduleDaily(
      id: _morningId,
      title: '🌅 أذكار الصباح',
      body: 'حصّن يومك — اقرأ أذكار الصباح الآن',
      hour: 6,
      minute: 0,
    );
  }

  static Future<void> scheduleEvening(bool enable) async {
    if (kIsWeb) return;
    if (!enable) {
      await _plugin.cancel(_eveningId);
      return;
    }
    await _scheduleDaily(
      id: _eveningId,
      title: '🌙 أذكار المساء',
      body: 'حصّن ليلتك — اقرأ أذكار المساء الآن',
      hour: 17,
      minute: 0,
    );
  }

  /// Rebuilds tomorrow's prayer alerts from the reader's settings.
  ///
  /// Called after every prayer-times load, because the times move each day and
  /// a schedule laid down once would drift. Ids are derived from the prayer
  /// and moment, so rescheduling replaces rather than piles up.
  static Future<void> schedulePrayerAlerts(
      Map<AlertPrayer, DateTime> times) async {
    for (final prayer in AlertPrayer.values) {
      final at = times[prayer];
      for (final when in AlertWhen.values) {
        final id = 100 + prayer.index * 10 + when.index;
        await _plugin.cancel(id);

        final mode = PrayerAlerts.modeFor(prayer, when);
        if (mode == AlertMode.off || at == null) continue;

        final moment = when == AlertWhen.before
            ? at.subtract(Duration(minutes: PrayerAlerts.lead.value))
            : at;
        if (moment.isBefore(DateTime.now())) continue;

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
        );
      }
    }
  }

  static Future<void> _scheduleAt({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required AlertMode mode,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      // A channel per mode: Android fixes sound and vibration to the channel,
      // so one channel could never be silent for one prayer and audible for
      // the next.
      'salahulddin_prayer_${mode.id}',
      'مواقيت الصلاة — ${mode.label}',
      channelDescription: 'تنبيهات الصلاة',
      importance: Importance.max,
      priority: Priority.high,
      playSound: mode.plays,
      enableVibration: mode.vibrates,
    );
    final iosDetails = DarwinNotificationDetails(presentSound: mode.plays);

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

  static Future<void> _scheduleDaily({
    required int id,
    required String title,
    required String body,
    required int hour,
    required int minute,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'salahulddin_azkar_channel',
      'أذكار salahulddin-AZKAR',
      channelDescription: 'تذكيرات يومية بأذكار الصباح والمساء',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduled,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }
}
