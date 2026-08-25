import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/notification_service.dart';

/// Reported as "notifications never appear on the phone from outside", while
/// the test notification arrived every time. The difference was the channel.
///
/// Android reads a channel's importance as how much it may interrupt: at
/// default it goes into the shade and no further — no banner, nothing on the
/// lock screen. Two of the three scheduled kinds were created that way, so
/// they arrived and were never seen. And the value is fixed when the channel
/// is created — an app may only ever lower it — so the repair needed new ids,
/// not a new number under the old ones.
void main() {
  test('every scheduled notification may interrupt', () {
    expect(NotificationService.reminderImportance, Importance.max,
        reason: 'below high there is no banner and no lock screen');
    expect(NotificationService.reminderPriority, Priority.high);
  });

  test('the channels carry ids that were made afresh', () {
    // The quiet ones cannot be raised, so they had to be replaced. If a
    // channel here ever goes back to one of those names, it inherits the
    // importance it was born with and falls silent again.
    const quiet = [
      'salahulddin_dhikr_reminder',
      'salahulddin_daily',
      'salahulddin_prayer_silent',
    ];
    for (final channel in NotificationService.channels) {
      expect(quiet, isNot(contains(channel)),
          reason: '$channel would inherit the old importance');
    }
  });

  test('each kind speaks on its own channel', () {
    expect(NotificationService.channels.toSet().length,
        NotificationService.channels.length,
        reason: 'one channel for two kinds means one switch for both');
    expect(NotificationService.channels, isNotEmpty);
  });
}
