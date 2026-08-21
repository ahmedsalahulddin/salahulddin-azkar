import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/prayer_settings.dart';
import 'package:salahulddin_azkar/widgets/prayer_times_card.dart';
import 'package:salahulddin_azkar/widgets/rotating_verse.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The Asr rule is the one setting that moves a single prayer and leaves the
/// other four exactly where they were. So a card that never re-read it looked
/// like a wrong Asr rather than like settings that do nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrayerSettings.load();
  });

  // The card carries a rotating verse, whose timer is meant to outlive any one
  // screen. It must not outlive the test.
  tearDown(VerseRotation.debugStop);

  const riyadh = (lat: 24.7136, lng: 46.6753);

  PrayerTimes timesNow() => PrayerTimes.today(
        Coordinates(riyadh.lat, riyadh.lng),
        PrayerSettings.parametersFor(riyadh.lat, riyadh.lng),
      );

  group('the two schools', () {
    test('the majority is the default — nobody is put on the other by accident',
        () {
      expect(PrayerSettings.school.value, AsrSchool.standard);
      expect(AsrSchool.standard.madhab, Madhab.shafi);
    });

    test('changing the school moves Asr, and moves nothing else', () async {
      final before = timesNow();
      await PrayerSettings.setSchool(AsrSchool.hanafi);
      final after = timesNow();

      expect(after.asr, isNot(before.asr));
      expect(after.asr.difference(before.asr).inMinutes, greaterThan(20),
          reason: 'the two rules are the better part of an hour apart');

      // Everything else is untouched, which is exactly why a stale card looks
      // like a broken Asr.
      expect(after.fajr, before.fajr);
      expect(after.dhuhr, before.dhuhr);
      expect(after.maghrib, before.maghrib);
      expect(after.isha, before.isha);
    });

    test('the choice survives the next run', () async {
      await PrayerSettings.setSchool(AsrSchool.hanafi);
      PrayerSettings.school.value = AsrSchool.standard;

      await PrayerSettings.load();
      expect(PrayerSettings.school.value, AsrSchool.hanafi);
    });
  });

  testWidgets('the card re-reads the settings when they change',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: PrayerTimesCard()),
      ),
    ));

    // runAsync, because locating goes out to a platform channel and a widget
    // test's clock does not turn one. pumpAndSettle is no use either — the
    // card's countdown ticks once a second and never settles.
    Future<void> settle() async {
      await tester.runAsync(() => Future<void>.delayed(
          const Duration(milliseconds: 120)));
      await tester.pump();
    }

    for (var i = 0; i < 3; i++) {
      await settle();
    }

    List<String> shown() => tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .toList();

    final before = shown();
    expect(before.any((t) => t.contains('العصر')), isTrue,
        reason: 'the card should be showing the five prayers by now');

    await PrayerSettings.setSchool(AsrSchool.hanafi);
    for (var i = 0; i < 3; i++) {
      await settle();
    }

    expect(shown(), isNot(before),
        reason: 'a card that never re-reads the setting shows the old Asr');

    // Inside the body, not in tearDown: the pending-timer check runs before
    // tearDown does, and the rotation's timer is deliberately app-lifetime.
    VerseRotation.debugStop();
  });
}
