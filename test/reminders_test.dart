import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/adhans.dart';
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

    test('five prayers, two moments — and sunrise is not one', () {
      expect(AlertPrayer.values.length, 5);
      expect(AlertWhen.values.length, 2);
      // Sunrise is not a prayer; an alarm for it calls people to nothing.
      expect(AlertPrayer.values.map((p) => p.name), isNot(contains('الشروق')));
    });

    test('notification and sound are independent, and both can be on', () {
      // The point of the rewrite: a reader may want the phone buzzing in a
      // pocket AND the adhan playing.
      const both = AlertMode(notify: true, sound: true);
      expect(both.isOff, isFalse);
      expect(both.label, 'إشعار وصوت');
    });

    test('choosing sound brings its notification with it', () {
      // A sound arrives on a notification; there is nothing for it to ride
      // otherwise.
      expect(AlertMode.off.withSound(true).notify, isTrue);
      // And silencing the notification silences the sound with it.
      const both = AlertMode(notify: true, sound: true);
      expect(both.withNotify(false).sound, isFalse);
    });

    test('a setting written by the old three-mode build still means the same',
        () {
      // Upgrading must not switch anyone off without telling them.
      expect(AlertMode.decode('off').isOff, isTrue);
      expect(AlertMode.decode('notify').notify, isTrue);
      expect(AlertMode.decode('notify').sound, isFalse);
      expect(AlertMode.decode('sound').sound, isTrue);
      expect(AlertMode.decode('sound').notify, isTrue);
      // And the new format round-trips.
      const both = AlertMode(notify: true, sound: true);
      expect(AlertMode.decode(both.encode()).sound, isTrue);
      expect(AlertMode.decode(null).isOff, isTrue);
      expect(AlertMode.decode('rubbish').isOff, isTrue);
    });

    test('muting everything keeps the notifications and drops the sounds',
        () async {
      await PrayerAlerts.setAll(
          AlertWhen.onTime, const AlertMode(notify: true, sound: true));
      expect(PrayerAlerts.anySound, isTrue);

      await PrayerAlerts.muteEverything();
      expect(PrayerAlerts.anySound, isFalse);
      expect(PrayerAlerts.anyOn, isTrue,
          reason: 'muting is not turning off — the alerts still arrive');
    });

    test('only the call itself gets an adhan, never the early warning', () {
      // A full adhan fifteen minutes early would send people out.
      expect(PrayerAlerts.bundledResource, 'adhan_makkah');
      expect(Adhans.byId('makkah').isBundled, isTrue);
      expect(Adhans.byId('afasy').isBundled, isFalse);
      // A downloadable adhan has no resource yet, so the alert keeps the
      // system tone rather than falling silent.
      PrayerAlerts.adhan.value = 'afasy';
      expect(PrayerAlerts.bundledResource, isNull);
      PrayerAlerts.adhan.value = 'makkah';
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

      await PrayerAlerts.setMode(AlertPrayer.fajr, AlertWhen.onTime,
          const AlertMode(notify: true, sound: true));
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
          AlertPrayer.asr, AlertWhen.before, const AlertMode(notify: true));
      expect(rebuilds, 0,
          reason: 'scheduling against times we do not have would be guessing');
    });

    test('a setting survives the next run, and keys never collide', () async {
      await PrayerAlerts.setMode(AlertPrayer.fajr, AlertWhen.before,
          const AlertMode(notify: true, sound: true));
      await PrayerAlerts.setMode(
          AlertPrayer.fajr, AlertWhen.onTime, const AlertMode(notify: true));

      await PrayerAlerts.load();
      expect(PrayerAlerts.modeFor(AlertPrayer.fajr, AlertWhen.before).sound,
          isTrue);
      expect(PrayerAlerts.modeFor(AlertPrayer.fajr, AlertWhen.onTime).sound,
          isFalse,
          reason: 'the two moments of one prayer must not share a key');
      expect(
          PrayerAlerts.modeFor(AlertPrayer.asr, AlertWhen.before).isOff,
          isTrue);
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
