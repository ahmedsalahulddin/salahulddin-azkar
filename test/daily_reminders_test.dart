import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/adhans.dart';
import 'package:salahulddin_azkar/screens/settings_screen.dart';
import 'package:salahulddin_azkar/services/daily_reminders.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adhkar belong to hours, not to whims: the morning ones are said between
/// Fajr and noon, the evening ones between Asr and Maghrib. The clamp lives in
/// the model rather than the picker, so a value arriving from anywhere — an
/// old install, a hand-edited store — is still a time they can be said at.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DailyReminders.load();
  });

  group('the windows hold', () {
    test('morning cannot be set past 11:59, as asked', () async {
      expect(DailyReminders.morningWindow.latest, 11 * 60 + 59);

      await DailyReminders.setMorning(at: const DayTime(20 * 60));
      expect(DailyReminders.morningAt.value.minutes,
          DailyReminders.morningWindow.latest,
          reason: 'an evening hour is not a morning adhkar time');

      await DailyReminders.setMorning(at: const DayTime(1 * 60));
      expect(DailyReminders.morningAt.value.minutes,
          DailyReminders.morningWindow.earliest,
          reason: 'before Fajr is before the adhkar exist');
    });

    test('evening runs from Asr to Maghrib and no further', () async {
      await DailyReminders.setEvening(at: const DayTime(9 * 60));
      expect(DailyReminders.eveningAt.value.minutes,
          DailyReminders.eveningWindow.earliest);

      await DailyReminders.setEvening(at: const DayTime(23 * 60));
      expect(DailyReminders.eveningAt.value.minutes,
          DailyReminders.eveningWindow.latest);
    });

    test('a time inside the window is left exactly alone', () async {
      await DailyReminders.setMorning(at: const DayTime(7 * 60 + 30));
      expect(DailyReminders.morningAt.value.minutes, 7 * 60 + 30);
    });

    test('a stored value outside the window is clamped on load', () async {
      // Written by an older build, or by hand. Loading must not trust it.
      SharedPreferences.setMockInitialValues({'@noor_morning_at': 23 * 60});
      await DailyReminders.load();
      expect(DailyReminders.morningAt.value.minutes,
          lessThanOrEqualTo(DailyReminders.morningWindow.latest));
    });
  });

  group('the verse pair', () {
    test('off until asked for, then two distinct times', () async {
      expect(DailyReminders.verseOn.value, isFalse);

      await DailyReminders.setVerse(on: true);
      expect(DailyReminders.verseOn.value, isTrue);
      expect(DailyReminders.verseFirst.value.minutes,
          isNot(DailyReminders.verseSecond.value.minutes),
          reason: 'two reminders at one time is one reminder');
    });

    test('the defaults are the ones asked for: late morning and late night',
        () {
      expect(DailyReminders.verseFirst.value.hour, 10);
      expect(DailyReminders.verseSecond.value.hour, 22);
      expect(DailyReminders.verseSecond.value.minute, 30);
    });

    test('a change survives the next run', () async {
      await DailyReminders.setVerse(on: true, first: const DayTime(9 * 60));
      await DailyReminders.load();
      expect(DailyReminders.verseOn.value, isTrue);
      expect(DailyReminders.verseFirst.value.minutes, 9 * 60);
    });
  });

  group('reading the clock', () {
    test('times read the way an Arabic reader says them', () {
      expect(const DayTime(0).label, '12:00 ص');
      expect(const DayTime(12 * 60).label, '12:00 م');
      expect(const DayTime(13 * 60 + 5).label, '1:05 م');
      expect(const DayTime(11 * 60 + 59).label, '11:59 ص');
    });
  });

  group('the adhans', () {
    test('two are bundled and the rest carry a source', () {
      final bundled = Adhans.all.where((a) => a.isBundled);
      expect(bundled.length, 2);
      for (final adhan in Adhans.all.where((a) => !a.isBundled)) {
        expect(Uri.parse(adhan.url!).scheme, 'https');
      }
      expect(Adhans.all.map((a) => a.id).toSet().length, Adhans.all.length);
    });

    test('an unknown id falls back rather than throwing', () {
      expect(Adhans.byId('nothing-like-this').isBundled, isTrue);
    });
  });

  group('one card each', () {
    testWidgets('the morning and evening adhkar are offered once, not twice',
        (tester) async {
      // They were offered twice for a while: the old fixed-hour pair sat in
      // the settings beside the new one the reader sets the time on, and both
      // scheduled a reminder. Two cards meant two notifications a day.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SettingsScreen(embedded: true)),
        ),
      ));
      await tester.pump();

      expect(find.text('أذكار الصباح'), findsOneWidget);
      expect(find.text('أذكار المساء'), findsOneWidget);
    });
  });
}
