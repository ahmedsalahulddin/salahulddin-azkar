import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/memorisation.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/screens/memorisation_test_screen.dart';

/// Four ways of asking, because one shape of question tests one thing. The
/// questions are generated, so what has to hold is that every generated one is
/// answerable: a right answer present exactly once, distractors that are not
/// secretly right, and a solution that can actually be reached.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<QuestionBank> bank(int surah) async =>
      QuestionBank(await QuranService.surah(surah));

  group('the drill settings', () {
    test('difficulty hides progressively more of the ayah', () {
      expect(TestDifficulty.easy.hiddenWords, 1);
      expect(TestDifficulty.medium.hiddenWords, 3);
      // -1 stands for the whole ayah.
      expect(TestDifficulty.hard.hiddenWords, -1);
    });

    test('every mode names itself and says what it does', () {
      expect(TestMode.values.length, 4);
      expect(TestMode.values.map((m) => m.label).toSet().length, 4);
      expect(TestMode.values.every((m) => m.hint.trim().isNotEmpty), isTrue);
    });
  });

  group('إكمال الآية', () {
    test('what is shown plus what is hidden is the whole ayah', () async {
      final b = await bank(112);
      for (final d in TestDifficulty.values) {
        for (var i = 0; i < b.length(TestMode.complete); i++) {
          final q = b.build(TestMode.complete, i, d);
          expect([...q.shown, ...q.hidden].join(' '), q.ayah.text,
              reason: 'ayah ${q.ayah.number} at ${d.label} lost words');
          expect(q.hidden, isNotEmpty, reason: 'nothing was withheld');
        }
      }
    });

    test('something is always left to cue the recall, except on hard',
        () async {
      // An-Nas: four to six words an ayah, so the easy level has to hold up on
      // short ayahs too.
      final b = await bank(114);
      for (var i = 0; i < b.length(TestMode.complete); i++) {
        expect(b.build(TestMode.complete, i, TestDifficulty.easy).shown,
            isNotEmpty);
        expect(b.build(TestMode.complete, i, TestDifficulty.hard).shown,
            isEmpty);
      }
    });
  });

  group('ترتيب الكلمات', () {
    test('following the solution rebuilds the ayah exactly', () async {
      final b = await bank(108);
      for (var i = 0; i < b.length(TestMode.order); i++) {
        final q = b.build(TestMode.order, i, TestDifficulty.medium);
        final rebuilt = [for (final slot in q.solution) q.scrambled[slot]];
        expect(rebuilt.join(' '), q.ayah.text);
      }
    });

    test('the solution is a permutation — every chip is used once', () async {
      final b = await bank(103);
      for (var i = 0; i < b.length(TestMode.order); i++) {
        final q = b.build(TestMode.order, i, TestDifficulty.medium);
        expect(q.solution.toSet().length, q.scrambled.length);
        expect(q.solution.length, q.scrambled.length);
      }
    });
  });

  group('الكلمة الناقصة', () {
    test('the gap plus its answer restores the ayah', () async {
      final b = await bank(112);
      for (var i = 0; i < b.length(TestMode.missing); i++) {
        final q = b.build(TestMode.missing, i, TestDifficulty.medium);
        final restored = [...q.before, q.options[q.answer], ...q.after];
        expect(restored.join(' '), q.ayah.text);
      }
    });

    test('no option is offered twice, so only one can be right', () async {
      final b = await bank(2); // long enough for a real pool of distractors
      for (var i = 0; i < 40; i++) {
        final q = b.build(TestMode.missing, i, TestDifficulty.medium);
        expect(q.options.toSet().length, q.options.length,
            reason: 'a duplicate option would make two answers correct');
        expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      }
    });
  });

  group('الآية التالية', () {
    test('the right option really is the following ayah', () async {
      final b = await bank(78);
      for (var i = 0; i < b.length(TestMode.next); i++) {
        final q = b.build(TestMode.next, i, TestDifficulty.medium);
        expect(q.options[q.answer], b.surah.ayahs[i + 1].text);
        expect(q.options.toSet().length, q.options.length);
      }
    });

    test('it never asks what follows the last ayah', () async {
      final b = await bank(112);
      expect(b.length(TestMode.next), b.surah.ayahs.length - 1);
    });

    test('a surah of one ayah simply cannot be asked this way', () async {
      final b = await bank(108); // three ayahs — fine
      expect(b.supports(TestMode.next), isTrue);
      final kawthar = QuestionBank(Surah(
          number: 1,
          name: 'اختبار',
          ayahs: [await bank(112).then((x) => x.surah.ayahs.first)]));
      expect(kawthar.supports(TestMode.next), isFalse);
    });
  });

  test('the same question twice is the same question', () async {
    // Rebuilding the screen must not reshuffle the options under the finger.
    final b = await bank(36);
    for (final mode in TestMode.values) {
      final a = b.build(mode, 5, TestDifficulty.medium);
      final c = b.build(mode, 5, TestDifficulty.medium);
      expect(a.options, c.options, reason: '${mode.label} reshuffled');
      expect(a.scrambled, c.scrambled, reason: '${mode.label} reshuffled');
      expect(a.answer, c.answer);
    }
  });

  group('on screen', () {
    Future<void> pumpTest(WidgetTester tester, int surah) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final info = (await QuranService.index()).firstWhere((s) => s.number == surah);
      await tester.pumpWidget(MaterialApp(home: MemorisationTestScreen(info: info)));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('the withheld words leave a visible gap, not a blank card',
        (tester) async {
      await pumpTest(tester, 112);

      // The old drill painted the hidden words in the background colour, so
      // the card looked empty and the reader could not tell how much was gone.
      expect(find.text('؟'), findsWidgets);
      expect(find.text('اكشف'), findsOneWidget);
      expect(find.text('تذكّرتها'), findsNothing);

      await tester.tap(find.text('اكشف'));
      await tester.pump();
      expect(find.text('تذكّرتها'), findsOneWidget);

      await tester.tap(find.text('تذكّرتها'));
      await tester.pump();
      expect(find.textContaining('السؤال ٢ من ٤'), findsOneWidget);
    });

    testWidgets('all four ways are offered, and switching restarts the score',
        (tester) async {
      await pumpTest(tester, 112);
      for (final mode in TestMode.values) {
        expect(find.text(mode.label), findsOneWidget);
      }

      await tester.tap(find.text('اكشف'));
      await tester.pump();
      await tester.tap(find.text('تذكّرتها'));
      await tester.pump();
      expect(find.textContaining('السؤال ٢'), findsOneWidget);

      await tester.tap(find.text(TestMode.missing.label));
      await tester.pump();
      expect(find.textContaining('السؤال ١'), findsOneWidget);
      expect(find.textContaining('✓ ٠'), findsOneWidget);
    });

    testWidgets('finishing reports a score', (tester) async {
      await pumpTest(tester, 112);

      for (var i = 0; i < 4; i++) {
        await tester.tap(find.text('اكشف'));
        await tester.pump();
        await tester.tap(find.text('تذكّرتها'));
        await tester.pump();
      }

      expect(find.text('%١٠٠'), findsOneWidget);
      expect(find.textContaining('تذكّرت ٤ من ٤'), findsOneWidget);
      expect(find.text('أعد الاختبار'), findsOneWidget);
    });
  });
}
