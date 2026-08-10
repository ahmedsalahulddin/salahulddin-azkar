import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

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
