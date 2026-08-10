import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/screens/surah_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Assertions here deliberately avoid hand-typed Arabic literals: the bundled
/// KFGQPC text uses Mushaf-specific code points that do not survive being
/// retyped, so comparisons are made against the loaded data itself.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Quran assets', () {
    test('index holds all 114 surahs and 6236 ayahs', () async {
      final index = await QuranService.index();
      expect(index.length, 114);
      expect(index.fold<int>(0, (sum, s) => sum + s.ayahCount), 6236);
      expect(index.first.nameEn, 'Al-Faatiha');
      expect(index.last.nameEn, 'An-Naas');
      expect(index.map((s) => s.number), List.generate(114, (i) => i + 1));
    });

    test('every surah file matches the count the index promises', () async {
      for (final info in await QuranService.index()) {
        final surah = await QuranService.surah(info.number);
        expect(surah.ayahs.length, info.ayahCount,
            reason: 'surah ${info.number} ayah count mismatch');
        expect(surah.ayahs.map((a) => a.number),
            List.generate(info.ayahCount, (i) => i + 1),
            reason: 'surah ${info.number} ayah numbering is not contiguous');
        expect(surah.ayahs.any((a) => a.text.trim().isEmpty), isFalse,
            reason: 'surah ${info.number} has an empty ayah');
      }
    });

    test('Basmala is a header everywhere except Al-Fatiha and At-Tawbah',
        () async {
      final fatiha = await QuranService.surah(1);
      expect(QuranService.basmala, isNotEmpty);
      // Al-Fatiha counts the Basmala as ayah 1, and it must match the string
      // the reader header renders — character for character.
      expect(fatiha.ayahs.first.text, QuranService.basmala);

      // No other surah may open with it, whole or partial.
      final basmalaWords = QuranService.basmala.split(' ');
      for (final info in await QuranService.index()) {
        if (info.number == 1) continue;
        final first = (await QuranService.surah(info.number)).ayahs.first.text;
        for (var i = 0; i < basmalaWords.length; i++) {
          final tail = basmalaWords.sublist(i).join(' ');
          expect(first.startsWith(tail), isFalse,
              reason: 'surah ${info.number} ayah 1 opens with a Basmala fragment');
        }
      }
    });

    test('only surahs 1 and 9 opt out of the Basmala header', () async {
      final index = await QuranService.index();
      expect(index.where((s) => !s.hasBasmala).map((s) => s.number), [1, 9]);
    });

    test('sajda verses are flagged', () async {
      var total = 0;
      for (final info in await QuranService.index()) {
        total += (await QuranService.surah(info.number))
            .ayahs
            .where((a) => a.isSajda)
            .length;
      }
      expect(total, 15);
      // As-Sajdah's prostration verse is the well-known one.
      final asSajdah = await QuranService.surah(32);
      expect(asSajdah.ayahs.where((a) => a.isSajda).length, 1);
    });

    test('ayah numbers render as Arabic-Indic digits', () {
      expect(QuranService.toArabicDigits(1), '١');
      expect(QuranService.toArabicDigits(286), '٢٨٦');
    });
  });

  testWidgets('SurahScreen renders the header and every ayah', (tester) async {
    // The verse list is lazy, so give it a surface tall enough to build all of
    // Al-Ikhlas rather than asserting against whatever happens to be on screen.
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Warm the cache so the screen's async load resolves within a pump.
    final info = (await QuranService.index()).firstWhere((s) => s.number == 112);
    final surah = await QuranService.surah(112);

    await tester.pumpWidget(MaterialApp(home: SurahScreen(info: info)));
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining(info.name), findsWidgets);
    // Basmala belongs to the header, not to ayah 1.
    expect(find.text(QuranService.basmala), findsOneWidget);
    for (final ayah in surah.ayahs) {
      expect(find.textContaining(ayah.text), findsOneWidget,
          reason: 'ayah ${ayah.number} is missing from the reader');
    }
  });
}
