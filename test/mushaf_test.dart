import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/screens/mushaf_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Mushaf page index', () {
    test('there are exactly 604 pages, numbered without gaps', () async {
      final pages = await QuranService.pages();
      expect(pages.length, QuranService.pageCount);
      expect(pages.map((p) => p.number), List.generate(604, (i) => i + 1));
      expect(pages.every((p) => p.juz >= 1 && p.juz <= 30), isTrue);
    });

    test('every ayah of the Quran sits on exactly one page', () async {
      final seen = <String>{};
      var counted = 0;

      for (final page in await QuranService.pages()) {
        expect(page.runs, isNotEmpty, reason: 'page ${page.number} is empty');
        for (final run in page.runs) {
          expect(run.first, lessThanOrEqualTo(run.last),
              reason: 'page ${page.number} has an inverted run');
          for (var a = run.first; a <= run.last; a++) {
            final key = '${run.surah}:$a';
            expect(seen.add(key), isTrue,
                reason: '$key appears on more than one page');
            counted++;
          }
        }
      }
      expect(counted, 6236);
    });

    test('page runs never point past the end of their surah', () async {
      final index = await QuranService.index();
      final ayahCounts = {for (final s in index) s.number: s.ayahCount};

      for (final page in await QuranService.pages()) {
        for (final run in page.runs) {
          expect(ayahCounts.containsKey(run.surah), isTrue,
              reason: 'page ${page.number} references surah ${run.surah}');
          expect(run.last, lessThanOrEqualTo(ayahCounts[run.surah]!),
              reason:
                  'page ${page.number} run ${run.surah}:${run.last} overruns the surah');
        }
      }
    });

    test('juz numbers only ever move forward through the Mushaf', () async {
      final pages = await QuranService.pages();
      for (var i = 1; i < pages.length; i++) {
        expect(pages[i].juz, greaterThanOrEqualTo(pages[i - 1].juz),
            reason: 'juz goes backwards at page ${pages[i].number}');
      }
      expect(pages.first.juz, 1);
      expect(pages.last.juz, 30);
    });

    test('each surah opens on a page that starts it', () async {
      for (final info in await QuranService.index()) {
        final page = await QuranService.pageOfSurah(info.number);
        expect(page, inInclusiveRange(1, 604));

        final pages = await QuranService.pages();
        final opener = pages[page - 1]
            .runs
            .where((r) => r.surah == info.number && r.startsSurah);
        expect(opener, isNotEmpty,
            reason: 'surah ${info.number} does not open on page $page');
      }
    });

    test('Al-Fatiha opens the Mushaf and An-Nas closes it', () async {
      expect(await QuranService.pageOfSurah(1), 1);
      final pages = await QuranService.pages();
      expect(pages.last.runs.last.surah, 114);
      expect(pages.last.runs.last.last, 6);
    });
  });

  testWidgets('MushafScreen opens on the requested page', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Warm the caches so the first frame after load has data.
    await QuranService.pages();
    await QuranService.index();

    await tester.pumpWidget(const MaterialApp(home: MushafScreen(initialPage: 2)));
    await tester.pump();
    await tester.pump();

    // The bar reports the position on its first row. The page carries the
    // same juz in its own header now, so the bar's copy is one of two — the
    // bar hides while reading, and the page has to stand alone when it does.
    expect(find.textContaining('صفحة ٢'), findsOneWidget);
    expect(find.textContaining('الجزء ١'), findsWidgets);
  });
}
