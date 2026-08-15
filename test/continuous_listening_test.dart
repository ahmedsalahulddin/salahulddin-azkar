import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/screens/listening_screen.dart';
import 'package:salahulddin_azkar/services/continuous_listening.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Listening straight through is the one player that must survive being left
/// alone: the phone in a pocket, the app in the background, a surah ending
/// with nobody there to press anything.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ContinuousListening.debugReset();
  });

  group('the Mushaf is read in a circle', () {
    test('An-Nas is followed by Al-Fatiha, not by silence', () {
      expect(ContinuousListening.nextSurah(114), 1);
      expect(ContinuousListening.nextSurah(1), 2);
    });

    test('going back from Al-Fatiha reaches An-Nas', () {
      expect(ContinuousListening.previousSurah(1), 114);
      expect(ContinuousListening.previousSurah(50), 49);
    });
  });

  group('where the listener left off', () {
    test('a fresh install begins at the opening of the Mushaf', () async {
      await ContinuousListening.load();
      expect(ContinuousListening.surah.value, 1);
      expect(ContinuousListening.ayah.value, 1);
    });

    test('the stored place is restored', () async {
      SharedPreferences.setMockInitialValues({
        '@noor_listen_surah': 12,
        '@noor_listen_ayah': 40,
      });
      await ContinuousListening.load();
      expect(ContinuousListening.surah.value, 12);
      expect(ContinuousListening.ayah.value, 40);
    });

    test('an ayah past the end of its surah starts the surah instead',
        () async {
      // Al-Fatiha has seven; a store claiming ayah 900 would ask the CDN for a
      // file that does not exist and play nothing at all.
      SharedPreferences.setMockInitialValues({
        '@noor_listen_surah': 1,
        '@noor_listen_ayah': 900,
      });
      await ContinuousListening.load();
      expect(ContinuousListening.ayah.value,
          lessThanOrEqualTo(ContinuousListening.infoFor(1)!.ayahCount));
    });

    test('a surah number outside the Mushaf is brought back inside', () async {
      SharedPreferences.setMockInitialValues({'@noor_listen_surah': 400});
      await ContinuousListening.load();
      expect(ContinuousListening.surah.value, inInclusiveRange(1, 114));
    });
  });

  group('naming what is playing', () {
    test('a surah is named, and an impossible number names nothing', () async {
      await ContinuousListening.load();
      expect(ContinuousListening.nameFor(1), isNotEmpty);
      expect(ContinuousListening.infoFor(1)!.ayahCount, 7);
      expect(ContinuousListening.nameFor(999), '');
    });
  });

  test('its playlist is tagged apart from the other players', () {
    // The Mushaf and the surah screen tag with the reciter's id. If this used
    // the same prefix, each would offer to pause the other's recitation under
    // its own name — a bug this app has already had once.
    expect(ContinuousListening.owner, 'listen:');
    expect('Husary_128kbps:2:255'.startsWith(ContinuousListening.owner),
        isFalse);
  });

  testWidgets('the card no longer opens a note promising the feature later',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ListeningScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The whole Mushaf is offered, not a redirect to the radio. Names carry
    // their diacritics in the index, so the surah is found by number.
    expect(find.text(ContinuousListening.nameFor(1)), findsWidgets);
    expect(find.textContaining('يُضاف تباعاً'), findsNothing);
    expect(find.text('إلى الإذاعة'), findsNothing);
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
  });
}
