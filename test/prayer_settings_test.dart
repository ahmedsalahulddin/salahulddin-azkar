import 'package:adhan/adhan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/prayer_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The calculation method is not a preference like a font size. Each authority
/// sets its own twilight angles, so the same coordinates give genuinely
/// different times — and using Makkah's method in Cairo does not shade the
/// answer, it makes it wrong.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrayerSettings.load();
  });

  const cairo = (lat: 30.0444, lng: 31.2357);
  const riyadh = (lat: 24.7136, lng: 46.6753);
  const london = (lat: 51.5072, lng: -0.1276);
  const karachi = (lat: 24.8607, lng: 67.0011);

  group('choosing the method', () {
    test('the default is automatic — nobody should have to know to look', () {
      expect(PrayerSettings.method.value, PrayerMethod.auto);
      expect(PrayerSettings.school.value, AsrSchool.standard);
    });

    test('ids and labels are unique, and a strange id falls back', () {
      expect(PrayerMethod.values.map((m) => m.id).toSet().length,
          PrayerMethod.values.length);
      expect(PrayerMethod.values.map((m) => m.label).toSet().length,
          PrayerMethod.values.length);
      expect(PrayerMethod.byId('from-a-later-build'), PrayerMethod.auto);
      expect(PrayerMethod.byId(null), PrayerMethod.auto);
    });

    test('each country gets the authority it actually uses', () {
      expect(PrayerMethod.forPlace(cairo.lat, cairo.lng),
          PrayerMethod.egyptian);
      expect(PrayerMethod.forPlace(riyadh.lat, riyadh.lng),
          PrayerMethod.ummAlQura);
      expect(PrayerMethod.forPlace(karachi.lat, karachi.lng),
          PrayerMethod.karachi);
      // Nowhere in particular falls to the Muslim World League.
      expect(PrayerMethod.forPlace(london.lat, london.lng),
          PrayerMethod.muslimWorldLeague);
    });

    test('a chosen method comes back on the next run', () async {
      await PrayerSettings.setMethod(PrayerMethod.egyptian);
      await PrayerSettings.setSchool(AsrSchool.hanafi);

      PrayerSettings.method.value = PrayerMethod.auto;
      PrayerSettings.school.value = AsrSchool.standard;
      await PrayerSettings.load();

      expect(PrayerSettings.method.value, PrayerMethod.egyptian);
      expect(PrayerSettings.school.value, AsrSchool.hanafi);
    });

    test('a manual choice overrides the place', () async {
      await PrayerSettings.setMethod(PrayerMethod.ummAlQura);
      expect(PrayerSettings.effective(cairo.lat, cairo.lng),
          PrayerMethod.ummAlQura);

      await PrayerSettings.setMethod(PrayerMethod.auto);
      expect(PrayerSettings.effective(cairo.lat, cairo.lng),
          PrayerMethod.egyptian);
    });
  });

  group('what it changes', () {
    PrayerTimes timesWith(PrayerMethod method, ({double lat, double lng}) at) {
      PrayerSettings.method.value = method;
      return PrayerTimes(
        Coordinates(at.lat, at.lng),
        DateComponents(2026, 8, 14),
        PrayerSettings.parametersFor(at.lat, at.lng),
      );
    }

    test('Makkah and Egypt do not give Cairo the same Isha', () {
      final makkah = timesWith(PrayerMethod.ummAlQura, cairo);
      final egypt = timesWith(PrayerMethod.egyptian, cairo);

      final gap = makkah.isha.difference(egypt.isha).abs();
      expect(gap.inMinutes, greaterThan(5),
          reason: 'the two methods should visibly disagree; if they do not, '
              'the setting is not reaching the calculation');
      // Fajr differs too, the angles being 18.5 and 19.5 degrees.
      expect(makkah.fajr.difference(egypt.fajr).abs().inMinutes,
          greaterThan(2));
    });

    test('the Asr rule moves Asr and nothing else', () {
      PrayerSettings.method.value = PrayerMethod.egyptian;

      PrayerSettings.school.value = AsrSchool.standard;
      final majority = PrayerTimes(
          Coordinates(cairo.lat, cairo.lng),
          DateComponents(2026, 8, 14),
          PrayerSettings.parametersFor(cairo.lat, cairo.lng));

      PrayerSettings.school.value = AsrSchool.hanafi;
      final hanafi = PrayerTimes(
          Coordinates(cairo.lat, cairo.lng),
          DateComponents(2026, 8, 14),
          PrayerSettings.parametersFor(cairo.lat, cairo.lng));

      expect(hanafi.asr.isAfter(majority.asr), isTrue,
          reason: 'the Hanafi Asr falls later');
      expect(hanafi.asr.difference(majority.asr).inMinutes, greaterThan(20));
      // The rule is about shadow length, so it touches nothing else.
      expect(hanafi.fajr, majority.fajr);
      expect(hanafi.maghrib, majority.maghrib);
    });

    test('every method produces a usable day', () {
      for (final method in PrayerMethod.values) {
        final times = timesWith(method, cairo);
        expect(times.fajr.isBefore(times.sunrise), isTrue, reason: method.id);
        expect(times.dhuhr.isBefore(times.asr), isTrue, reason: method.id);
        expect(times.maghrib.isBefore(times.isha), isTrue, reason: method.id);
      }
    });
  });
}
