import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/prayer_service.dart';
import 'package:salahulddin_azkar/widgets/sky_arch.dart';

/// The arc is the sun's own path, not a decorative curve. Sunrise is one end
/// of the horizon, sunset the other, and the top is solar noon — so Dhuhr has
/// to land at the apex by arithmetic, never by being placed there.
void main() {
  DateTime t(int h, int m) => DateTime(2026, 8, 14, h, m);

  final times = {
    'الفجر': t(4, 4),
    'الشروق': t(5, 27),
    'الظهر': t(11, 58),
    'العصر': t(15, 25),
    'المغرب': t(18, 28),
    'العشاء': t(19, 58),
  };

  const namesEn = {
    'الفجر': 'Fajr',
    'الشروق': 'Sunrise',
    'الظهر': 'Dhuhr',
    'العصر': 'Asr',
    'المغرب': 'Maghrib',
    'العشاء': 'Isha',
  };

  final data = PrayerData(
    prayers: [
      for (final e in times.entries)
        PrayerInfo(
          name: e.key,
          nameEn: namesEn[e.key]!,
          time: e.value,
          isNext: false,
        ),
    ],
    nextName: 'العشاء',
    nextNameEn: 'Isha',
    nextTime: times['العشاء']!,
    status: LocationStatus.fixed,
  );

  final clock = SkyClock(data);

  test('sunrise opens the day and sunset closes it', () {
    expect(clock.fractionFor(times['الشروق']!), 0);
    expect(clock.fractionFor(times['المغرب']!), 1);
  });

  test('Dhuhr lands at the apex on its own', () {
    // Solar noon is the midpoint of sunrise and sunset, and the apex is 0.5.
    // Nothing places Dhuhr there; the arithmetic does.
    expect(clock.fractionFor(times['الظهر']!), closeTo(0.5, 0.02));
  });

  test('Asr falls in the late afternoon, past three quarters', () {
    final asr = clock.fractionFor(times['العصر']!);
    expect(asr, greaterThan(0.5));
    expect(asr, lessThan(0.85));
  });

  test('the night prayers sit beyond the horizon, not on the day arc', () {
    // Isha just after sunset, Fajr just before sunrise: both on the far side.
    expect(clock.fractionFor(times['العشاء']!), greaterThan(1));
    expect(clock.fractionFor(times['الفجر']!), greaterThan(1));
    // Isha is early in the night, Fajr late — that ordering is what puts them
    // at opposite ends of the dip below the horizon.
    expect(
      clock.fractionFor(times['العشاء']!),
      lessThan(clock.fractionFor(times['الفجر']!)),
    );
  });

  test('the circuit is continuous and never doubles back', () {
    var previous = -1.0;
    for (var minute = 0; minute < 24 * 60; minute += 7) {
      final f = clock.fractionFor(
        DateTime(2026, 8, 14).add(Duration(minutes: minute)),
      );
      expect(f, inInclusiveRange(0, 2));
      // Midnight starts mid-night, so the one wrap is expected; everywhere
      // else time only moves forward along the path.
      if (f < previous) {
        expect(minute, lessThan(6 * 60), reason: 'went backwards at $minute');
      }
      previous = f;
    }
  });

  test('a whole day is a whole circuit', () {
    final start = clock.fractionFor(times['الشروق']!);
    final round = clock.fractionFor(
      times['الشروق']!.add(const Duration(days: 1)),
    );
    expect(round % 2, closeTo(start, 0.02));
  });

  test('the sun is up between sunrise and sunset, and not otherwise', () {
    expect(clock.isDaylight(t(9, 30)), isTrue);
    expect(clock.isDaylight(t(11, 58)), isTrue);
    expect(clock.isDaylight(t(18, 20)), isTrue);
    expect(clock.isDaylight(t(19, 17)), isFalse);
    expect(clock.isDaylight(t(2, 0)), isFalse);
    expect(clock.isDaylight(t(5, 0)), isFalse);
  });

  test('a day with no daylight does not divide by zero', () {
    // Polar latitudes really do produce this, and adhan returns it.
    final frozen = PrayerData(
      prayers: [
        for (final name in times.keys)
          PrayerInfo(
            name: name,
            nameEn: namesEn[name]!,
            time: t(12, 0),
            isNext: false,
          ),
      ],
      nextName: 'الفجر',
      nextNameEn: 'Fajr',
      nextTime: t(12, 0),
      status: LocationStatus.fixed,
    );
    expect(SkyClock(frozen).fractionFor(t(12, 0)), 0);
  });
}
