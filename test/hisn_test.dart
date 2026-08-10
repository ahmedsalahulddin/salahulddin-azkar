import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/hisn_data.dart';
import 'package:salahulddin_azkar/screens/hisn_chapter_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Hisn al-Muslim data', () {
    test('all 132 chapters load with unique ids and non-empty titles',
        () async {
      final chapters = await HisnService.chapters();
      expect(chapters.length, 132);
      expect(chapters.map((c) => c.id).toSet().length, 132);
      expect(chapters.any((c) => c.title.trim().isEmpty), isFalse);
    });

    test('every chapter has at least one dhikr and none are blank', () async {
      for (final c in await HisnService.chapters()) {
        expect(c.items, isNotEmpty, reason: 'chapter ${c.id} is empty');
        for (final d in c.items) {
          expect(d.text.trim(), isNotEmpty,
              reason: 'chapter ${c.id} dhikr ${d.number} is blank');
          expect(d.repeat, greaterThanOrEqualTo(1),
              reason: 'chapter ${c.id} dhikr ${d.number} has repeat < 1');
        }
        // Numbering restarts at 1 within each chapter and stays contiguous.
        expect(c.items.map((d) => d.number),
            List.generate(c.items.length, (i) => i + 1));
      }
    });

    test('totals match what the section advertises', () async {
      expect(await HisnService.totalAdhkar(), 267);
    });

    test('chapters are cached after the first read', () async {
      final first = await HisnService.chapters();
      final second = await HisnService.chapters();
      expect(identical(first, second), isTrue);
    });
  });

  testWidgets('tapping a dhikr counts it up and marks it done',
      (tester) async {
    final chapters = await HisnService.chapters();
    // A chapter whose first dhikr is said more than once, so the counter shows.
    final chapter = chapters.firstWhere((c) => c.items.first.repeat > 1);
    final dhikr = chapter.items.first;

    await tester
        .pumpWidget(MaterialApp(home: HisnChapterScreen(chapter: chapter)));
    await tester.pump();

    // Counter starts at zero of the required repeats.
    expect(find.textContaining('/'), findsWidgets);
    expect(find.textContaining('✓ تمّ'), findsNothing);

    for (var i = 0; i < dhikr.repeat; i++) {
      await tester.tap(find.textContaining(dhikr.text).first);
      await tester.pump();
    }

    expect(find.textContaining('✓ تمّ'), findsOneWidget);

    // Tapping again must not push the count past the target.
    await tester.tap(find.textContaining(dhikr.text).first);
    await tester.pump();
    expect(find.textContaining('✓ تمّ'), findsOneWidget);
  });
}
