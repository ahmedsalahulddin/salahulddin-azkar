import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/custom_reminders.dart';
import 'package:salahulddin_azkar/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const kahf = CustomReminder(
    id: 3,
    kind: ReminderKind.surah,
    surah: 18,
    days: {5},
    times: [9 * 60, 21 * 60],
  );

  test('a reminder survives being saved and read back', () {
    final back = CustomReminder.fromJson(kahf.toJson());
    expect(back.kind, ReminderKind.surah);
    expect(back.surah, 18);
    expect(back.days, {5});
    expect(back.times, [540, 1260]);
    expect(back.enabled, isTrue);
    expect(back.payload, 'surah:18');
  });

  test('adhkar reminders open their category', () {
    const morning = CustomReminder(
      id: 1,
      kind: ReminderKind.adhkar,
      adhkarId: 'morning',
      days: {1, 2, 3, 4, 5, 6, 7},
      times: [360],
    );
    expect(CustomReminder.fromJson(morning.toJson()).payload, 'adhkar:morning');
  });

  test('every alert of every reminder gets its own notification id', () {
    final ids = <int>{};
    for (var r = 1; r <= 50; r++) {
      for (var day = 1; day <= 7; day++) {
        for (var slot = 0; slot < CustomReminder.maxTimes; slot++) {
          final id = CustomReminder.notificationId(r, day, slot);
          expect(id, greaterThanOrEqualTo(CustomReminder.firstNotificationId));
          expect(ids.add(id), isTrue, reason: 'r$r d$day s$slot clashed');
        }
      }
    }
  });

  test(
    'saving keeps the list and hands every change to the scheduler',
    () async {
      SharedPreferences.setMockInitialValues({});
      var laidDown = 0;
      CustomReminders.onChanged = () async => laidDown++;
      CustomReminders.list.value = const [];

      await CustomReminders.save(kahf);
      await CustomReminders.save(kahf.copyWith(enabled: false));
      expect(CustomReminders.list.value, hasLength(1));
      expect(CustomReminders.list.value.single.enabled, isFalse);
      expect(CustomReminders.nextId(), 4);

      CustomReminders.list.value = const [];
      await CustomReminders.load();
      expect(CustomReminders.list.value.single.surah, 18);

      await CustomReminders.remove(3);
      expect(CustomReminders.list.value, isEmpty);
      expect(laidDown, 3);
      CustomReminders.onChanged = null;
    },
  );

  group('the next weekly time', () {
    late tz.Location riyadh;
    setUpAll(() {
      tzdata.initializeTimeZones();
      riyadh = tz.getLocation('Asia/Riyadh');
    });

    test('later the same day when the time is still ahead', () {
      // 2 Oct 2026 is a Friday.
      final now = tz.TZDateTime(riyadh, 2026, 10, 2, 8, 0);
      final at = NotificationService.nextWeekly(now, DateTime.friday, 9 * 60);
      expect(at, tz.TZDateTime(riyadh, 2026, 10, 2, 9, 0));
    });

    test('next week when today’s time has passed', () {
      final now = tz.TZDateTime(riyadh, 2026, 10, 2, 10, 0);
      final at = NotificationService.nextWeekly(now, DateTime.friday, 9 * 60);
      expect(at, tz.TZDateTime(riyadh, 2026, 10, 9, 9, 0));
    });

    test('the coming weekday otherwise', () {
      final now = tz.TZDateTime(riyadh, 2026, 10, 2, 10, 0);
      final at = NotificationService.nextWeekly(now, DateTime.sunday, 21 * 60);
      expect(at, tz.TZDateTime(riyadh, 2026, 10, 4, 21, 0));
      expect(at.weekday, DateTime.sunday);
    });
  });
}
