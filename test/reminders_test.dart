import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/adhans.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
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

  group('turning them on together', () {
    test('one action covers the call, the warning before it, and the dhikr',
        () async {
      // Twelve switches is a wall, not a choice. The card offers the three
      // that are asked for most as one tap — and this holds what that tap
      // actually leaves switched on.
      expect(PrayerAlerts.anyOn, isFalse, reason: 'nothing arrives unasked');

      const notify = AlertMode(notify: true);
      await PrayerAlerts.setAll(AlertWhen.before, notify);
      await PrayerAlerts.setAll(AlertWhen.onTime, notify);
      await DhikrReminder.apply(on: true);

      for (final prayer in AlertPrayer.values) {
        for (final when in AlertWhen.values) {
          expect(PrayerAlerts.modeFor(prayer, when).notify, isTrue,
              reason: '${prayer.name} — ${when.id}');
        }
      }
      expect(DhikrReminder.enabled.value, isTrue);
    });

    test('it does not switch a sound on for anyone', () async {
      // An adhan is chosen deliberately. Waking a household with one because
      // a button said "turn on notifications" is not a favour.
      const notify = AlertMode(notify: true);
      await PrayerAlerts.setAll(AlertWhen.onTime, notify);

      for (final prayer in AlertPrayer.values) {
        expect(PrayerAlerts.modeFor(prayer, AlertWhen.onTime).sound, isFalse);
      }
    });

    test('random duas are among the kinds the dhikr reminder can send', () {
      // "أدعية متنوعة" is picked out by the supplication opening اللهم.
      final duas =
          DhikrFlavour.values.firstWhere((f) => f.id == 'duas');
      expect(duas.marker, isNotNull);

      DhikrReminder.flavour.value = duas;
      final chosen = DhikrReminder.pool;

      expect(chosen, isNotEmpty,
          reason: 'a kind that sends nothing would silence the reminder');
      expect(chosen.length, lessThan(DhikrReminder.pool.length + 1));

      // Folded on both sides, the way the filter itself matches: the adhkar
      // are stored fully vowelled and the marker is written plainly.
      for (final dhikr in chosen) {
        expect(QuranService.searchKey(dhikr.text),
            contains(QuranService.searchKey(duas.marker!)),
            reason: 'a kind must send only its own kind');
      }

      // And it is a real narrowing, not the fallback quietly handing back
      // everything — which is what happened while the filter matched nothing.
      DhikrReminder.flavour.value = DhikrFlavour.all;
      expect(chosen.length, lessThan(DhikrReminder.pool.length),
          reason: 'asking for supplications used to send tasbih');
    });
  });

  group('silencing, and unsilencing', () {
    test('the silence can be lifted, and puts back exactly what it took',
        () async {
      // It used to act one way only: the sound flags were overwritten with
      // false and what had been on was gone, so the switch had nothing to
      // return to and did nothing when moved back.
      const loud = AlertMode(notify: true, sound: true);
      await PrayerAlerts.setAll(AlertWhen.onTime, loud);
      await PrayerAlerts.setAll(
          AlertWhen.before, const AlertMode(notify: true));
      expect(PrayerAlerts.anySound, isTrue);

      await PrayerAlerts.muteEverything();
      expect(PrayerAlerts.anySound, isFalse);
      // Silencing takes the sound and nothing else — the alerts still arrive.
      expect(PrayerAlerts.anyOn, isTrue);

      await PrayerAlerts.restoreSound();
      expect(PrayerAlerts.anySound, isTrue);
      for (final prayer in AlertPrayer.values) {
        expect(PrayerAlerts.modeFor(prayer, AlertWhen.onTime), loud);
        expect(PrayerAlerts.modeFor(prayer, AlertWhen.before).sound, isFalse,
            reason: 'what was silent before must stay silent');
      }
    });

    test('silencing twice does not forget what the first one saved', () async {
      const loud = AlertMode(notify: true, sound: true);
      await PrayerAlerts.setAll(AlertWhen.onTime, loud);

      await PrayerAlerts.muteEverything();
      await PrayerAlerts.muteEverything();

      await PrayerAlerts.restoreSound();
      expect(PrayerAlerts.anySound, isTrue,
          reason: 'the second mute must not overwrite the memory');
    });

    test('with nothing remembered it still does something', () async {
      // A reader who silenced the alerts before any of this existed. A switch
      // that moves and changes nothing is a switch nobody can trust.
      await PrayerAlerts.setAll(
          AlertWhen.onTime, const AlertMode(notify: true));
      expect(PrayerAlerts.anySound, isFalse);

      await PrayerAlerts.restoreSound();
      expect(PrayerAlerts.anySound, isTrue,
          reason: 'the adhan goes back on the call to prayer');
    });
  });

  group('a schedule that will not be written', () {
    tearDown(() {
      PrayerAlerts.onChanged = null;
      PrayerAlerts.lastTimes = const {};
    });

    test('the setting still applies when laying it down fails', () async {
      // What was reported: "أوقف التنبيهات" pressed once, stuck saying that
      // for ever, and doing nothing on every press after. Turning them off is
      // two calls, and the first threw on its way to the schedule — so the
      // second never ran, the alerts stayed on, and the button kept offering
      // to turn off what it had already failed to turn off.
      PrayerAlerts.lastTimes = {AlertPrayer.fajr: DateTime(2026, 8, 25, 4)};
      PrayerAlerts.onChanged = (_) async => throw StateError('no channel');

      await PrayerAlerts.setAll(
          AlertWhen.onTime, const AlertMode(notify: true));
      expect(PrayerAlerts.anyOn, isTrue,
          reason: 'switching on must survive a schedule that fails');

      await PrayerAlerts.setAll(AlertWhen.before, AlertMode.off);
      await PrayerAlerts.setAll(AlertWhen.onTime, AlertMode.off);
      expect(PrayerAlerts.anyOn, isFalse,
          reason: 'and so must switching off — both calls have to run');
    });

    test('silencing survives it too', () async {
      PrayerAlerts.lastTimes = {AlertPrayer.fajr: DateTime(2026, 8, 25, 4)};
      PrayerAlerts.onChanged = (_) async => throw StateError('no channel');

      await PrayerAlerts.setAll(
          AlertWhen.onTime, const AlertMode(notify: true, sound: true));
      await PrayerAlerts.muteEverything();
      expect(PrayerAlerts.anySound, isFalse);

      await PrayerAlerts.restoreSound();
      expect(PrayerAlerts.anySound, isTrue);
    });
  });
}
