import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/dhikr_reminder.dart';
import 'package:salahulddin_azkar/services/prayer_alerts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Reminders are the one feature that reaches a reader when the app is closed,
/// so the arithmetic behind them has to hold without anyone watching.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrayerAlerts.load();
    await DhikrReminder.load();
  });

  group('prayer alerts', () {
    test('nothing announces itself unasked', () {
      for (final prayer in AlertPrayer.values) {
        for (final when in AlertWhen.values) {
          expect(PrayerAlerts.modeFor(prayer, when), AlertMode.off);
        }
      }
      expect(PrayerAlerts.anyOn, isFalse);
    });

    test('five prayers, two moments, three modes — and sunrise is not one', () {
      expect(AlertPrayer.values.length, 5);
      expect(AlertWhen.values.length, 2);
      expect(AlertMode.values.length, 3);
      // Sunrise is not a prayer; an alarm for it calls people to nothing.
      expect(AlertPrayer.values.map((p) => p.name), isNot(contains('الشروق')));
    });

    test('each mode means something distinct to the system', () {
      expect(AlertMode.off.vibrates, isFalse);
      expect(AlertMode.off.plays, isFalse);
      expect(AlertMode.notify.vibrates, isTrue);
      expect(AlertMode.notify.plays, isFalse);
      expect(AlertMode.sound.plays, isTrue);
    });

    test('changing a setting rebuilds the schedule at once', () async {
      // Without this a reader turns an alert on and nothing happens until the
      // prayer times reload — which, if the app stays open, may be never.
      var rebuilds = 0;
      PrayerAlerts.lastTimes = {
        AlertPrayer.fajr: DateTime(2026, 8, 14, 4, 4),
        AlertPrayer.isha: DateTime(2026, 8, 14, 19, 58),
      };
      PrayerAlerts.onChanged = (_) async => rebuilds++;
      addTearDown(() => PrayerAlerts.onChanged = null);

      await PrayerAlerts.setMode(
          AlertPrayer.fajr, AlertWhen.onTime, AlertMode.sound);
      expect(rebuilds, 1);

      await PrayerAlerts.setLead(30);
      expect(rebuilds, 2, reason: 'the lead time moves every early alert');
    });

    test('nothing is rebuilt before any times are known', () async {
      var rebuilds = 0;
      PrayerAlerts.lastTimes = const {};
      PrayerAlerts.onChanged = (_) async => rebuilds++;
      addTearDown(() => PrayerAlerts.onChanged = null);

      await PrayerAlerts.setMode(
          AlertPrayer.asr, AlertWhen.before, AlertMode.notify);
      expect(rebuilds, 0,
          reason: 'scheduling against times we do not have would be guessing');
    });

    test('a setting survives the next run, and keys never collide', () async {
      await PrayerAlerts.setMode(
          AlertPrayer.fajr, AlertWhen.before, AlertMode.sound);
      await PrayerAlerts.setMode(
          AlertPrayer.fajr, AlertWhen.onTime, AlertMode.notify);

      await PrayerAlerts.load();
      expect(PrayerAlerts.modeFor(AlertPrayer.fajr, AlertWhen.before),
          AlertMode.sound);
      expect(PrayerAlerts.modeFor(AlertPrayer.fajr, AlertWhen.onTime),
          AlertMode.notify,
          reason: 'the two moments of one prayer must not share a key');
      expect(PrayerAlerts.modeFor(AlertPrayer.asr, AlertWhen.before),
          AlertMode.off);
      expect(PrayerAlerts.anyOn, isTrue);
    });
  });

  group('dhikr reminders', () {
    test('off until asked for', () {
      expect(DhikrReminder.enabled.value, isFalse);
    });

    test('the slots fall inside the waking window, evenly and in order', () {
      DhikrReminder.fromHour.value = 8;
      DhikrReminder.toHour.value = 22;
      DhikrReminder.perDay.value = 5;

      final slots = DhikrReminder.slotMinutes();
      expect(slots.length, 5);
      for (final minute in slots) {
        expect(minute, greaterThanOrEqualTo(8 * 60));
        expect(minute, lessThan(22 * 60));
      }
      for (var i = 1; i < slots.length; i++) {
        expect(slots[i], greaterThan(slots[i - 1]));
      }
      // Evenly, so a reader can be ready — randomness only looks like a fault.
      final gaps = [
        for (var i = 1; i < slots.length; i++) slots[i] - slots[i - 1]
      ];
      expect(gaps.toSet().length, 1);
    });

    test('a backwards or empty window schedules nothing at all', () {
      DhikrReminder.fromHour.value = 22;
      DhikrReminder.toHour.value = 8;
      expect(DhikrReminder.slotMinutes(), isEmpty);

      DhikrReminder.fromHour.value = 8;
      DhikrReminder.toHour.value = 22;
      DhikrReminder.perDay.value = 0;
      expect(DhikrReminder.slotMinutes(), isEmpty);
    });

    test('only adhkar short enough to read at a glance are sent', () {
      final pool = DhikrReminder.pool;
      expect(pool, isNotEmpty, reason: 'nothing to send is a dead feature');
      for (final dhikr in pool) {
        expect(dhikr.text.length, lessThanOrEqualTo(90),
            reason: 'a long supplication truncated by the system is worse '
                'than not sending it');
      }
    });
  });
}
