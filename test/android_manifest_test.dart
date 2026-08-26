import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one part of the notification system no Dart test could reach.
///
/// Every scheduled reminder is an AlarmManager alarm whose PendingIntent
/// points at a receiver class. The plugin ships that class but declares
/// nothing in its own manifest — declaring it is the app's job, and the app
/// never did. So Android accepted every alarm, held it, fired it on time, and
/// delivered it to a component that did not exist. Nothing threw. Nothing
/// logged. pendingNotificationRequests() counted them all.
///
/// show() does not go through AlarmManager, which is why the immediate test
/// passed for weeks while not one real reminder ever arrived.
void main() {
  final manifest =
      File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

  test('a scheduled notification has somewhere to land', () {
    expect(
      manifest,
      contains('com.dexterous.flutterlocalnotifications'
          '.ScheduledNotificationReceiver'),
      reason: 'without this every zonedSchedule() fires into nothing',
    );
  });

  test('the alarms survive a restart', () {
    // Android drops every alarm on reboot. RECEIVE_BOOT_COMPLETED was already
    // asked for; nothing was listening for it.
    expect(
      manifest,
      contains('com.dexterous.flutterlocalnotifications'
          '.ScheduledNotificationBootReceiver'),
    );
    expect(manifest, contains('android.intent.action.BOOT_COMPLETED'));
    expect(manifest, contains('android.permission.RECEIVE_BOOT_COMPLETED'));
  });

  test('neither receiver is exposed to other apps', () {
    // They exist to receive this app's own alarms. Exported, any app on the
    // phone could fire the reader's notifications.
    for (final match in RegExp(r'<receiver\b[^>]*?ScheduledNotification[^>]*?>')
        .allMatches(manifest)) {
      expect(match.group(0), contains('android:exported="false"'),
          reason: match.group(0));
    }
  });

  test('the permission Play restricts is still not asked for', () {
    // Deliberately undeclared: Play grants USE_EXACT_ALARM to alarm clocks and
    // calendars, and this app schedules inexactly on purpose.
    expect(manifest, isNot(contains('android.permission.USE_EXACT_ALARM')));
  });

  /// Flutter only declares INTERNET in the debug and profile manifests.
  /// Release builds merge from `main` alone, so leaving it out there silently
  /// strips networking from the shipped APK: Mushaf page images fall back to
  /// text and streamed recitation fails, with no error anywhere.
  test('release manifest grants the permissions the app depends on', () {
    const required = {
      'android.permission.INTERNET': 'Mushaf page images and recitation',
      'android.permission.POST_NOTIFICATIONS': 'adhkar reminders',
      'android.permission.ACCESS_COARSE_LOCATION': 'prayer times',
    };

    for (final entry in required.entries) {
      expect(manifest, contains(entry.key),
          reason: 'release builds need ${entry.key} for ${entry.value}');
    }
  });
}
