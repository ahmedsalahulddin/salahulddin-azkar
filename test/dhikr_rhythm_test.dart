import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/screens/settings_screen.dart';
import 'package:salahulddin_azkar/services/dhikr_reminder.dart';
import 'package:salahulddin_azkar/services/prayer_alerts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The dhikr reminder arrived on a rhythm of its own — so many a day, evenly
/// spread. Tying it to the prayers was asked for and deferred; this is it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PrayerAlerts.lastTimes = const {};
    await DhikrReminder.load();
  });

  /// A day whose prayers fall at ordinary hours.
  void givePrayerTimes() {
    final day = DateTime(2026, 8, 15);
    PrayerAlerts.lastTimes = {
      AlertPrayer.fajr: day.add(const Duration(hours: 4, minutes: 30)),
      AlertPrayer.dhuhr: day.add(const Duration(hours: 12, minutes: 10)),
      AlertPrayer.asr: day.add(const Duration(hours: 15, minutes: 40)),
      AlertPrayer.maghrib: day.add(const Duration(hours: 18, minutes: 50)),
      AlertPrayer.isha: day.add(const Duration(hours: 20, minutes: 20)),
    };
  }

  test('the even rhythm is what a reader who chose nothing keeps', () {
    expect(DhikrReminder.rhythm.value, DhikrRhythm.spread);
    expect(DhikrReminder.slotMinutes().length, DhikrReminder.perDay.value);
  });

  test('tied to the prayers, one reminder lands before each of the five',
      () async {
    givePrayerTimes();
    await DhikrReminder.apply(beat: DhikrRhythm.beforePrayer);

    final slots = DhikrReminder.slotMinutes();
    expect(slots.length, 5, reason: 'five prayers, and sunrise is not one');
    // Fajr at 4:30 with the default lead of 45 minutes.
    expect(slots.first, 3 * 60 + 45);
    expect(slots.contains(12 * 60 + 10 - 45), isTrue);
  });

  test('the lead is the reader\'s to choose', () async {
    givePrayerTimes();
    await DhikrReminder.apply(
        beat: DhikrRhythm.beforePrayer, minutesBefore: 15);

    expect(DhikrReminder.slotMinutes().first, 4 * 60 + 15);
  });

  test('slots come back in order, whatever order the prayers arrived in', () {
    givePrayerTimes();
    DhikrReminder.rhythm.value = DhikrRhythm.beforePrayer;

    final slots = DhikrReminder.slotMinutes();
    expect(slots, List.of(slots)..sort());
  });

  test('a lead that crosses midnight wraps rather than going negative',
      () async {
    // Fajr at half past midnight — northern summer, or a bad store. A negative
    // minute would schedule nothing at all.
    PrayerAlerts.lastTimes = {
      AlertPrayer.fajr: DateTime(2026, 6, 21, 0, 20),
    };
    await DhikrReminder.apply(
        beat: DhikrRhythm.beforePrayer, minutesBefore: 45);

    for (final slot in DhikrReminder.slotMinutes()) {
      expect(slot, inInclusiveRange(0, 24 * 60 - 1));
    }
  });

  test('without prayer times it keeps the even rhythm rather than falling '
      'silent', () async {
    PrayerAlerts.lastTimes = const {};
    await DhikrReminder.apply(beat: DhikrRhythm.beforePrayer);

    // A first run, or a reader who never granted the location. Silence would
    // look like the setting turned the reminder off.
    expect(DhikrReminder.slotMinutes(), isNotEmpty);
    expect(DhikrReminder.slotMinutes().length, DhikrReminder.perDay.value);
  });

  test('the choice survives the next run', () async {
    await DhikrReminder.apply(
        beat: DhikrRhythm.beforePrayer, minutesBefore: 30);
    DhikrReminder.rhythm.value = DhikrRhythm.spread;

    await DhikrReminder.load();
    expect(DhikrReminder.rhythm.value, DhikrRhythm.beforePrayer);
    expect(DhikrReminder.lead.value, 30);
  });

  test('a lead not on the dial reads as the default', () async {
    SharedPreferences.setMockInitialValues({'@noor_dhikr_reminder_lead': 7});
    await DhikrReminder.load();
    expect(DhikrReminder.lead.value, 45);
  });

  testWidgets('the settings offer the choice, and the lead only when it applies',
      (tester) async {
    await DhikrReminder.apply(on: true, beat: DhikrRhythm.spread);

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SettingsScreen(embedded: true)),
      ),
    ));
    await tester.pump();

    expect(find.text('قبل كل صلاة'), findsOneWidget);
    expect(find.text('كم مرة في اليوم'), findsOneWidget);
    expect(find.text('قبل الأذان بـ'), findsNothing);

    // The card sits well below the fold of a test-sized screen.
    await tester.ensureVisible(find.text('قبل كل صلاة'));
    await tester.pump();
    await tester.tap(find.text('قبل كل صلاة'));
    await tester.pump();
    await tester.pump();

    // The count strip has nothing to say once the prayers set the times.
    expect(find.text('قبل الأذان بـ'), findsOneWidget);
    expect(find.text('كم مرة في اليوم'), findsNothing);
  });
}
