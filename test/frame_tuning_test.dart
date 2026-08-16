import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/screens/mushaf/appearance_tabs.dart';
import 'package:salahulddin_azkar/screens/mushaf/page_sheet.dart';
import 'package:salahulddin_azkar/widgets/frame_tuning.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the border sits could only be changed by editing the app and
/// shipping it, which meant describing "wrong" over screenshots and guessing
/// at what was meant. These hold the numbers the reader now sets themselves.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FrameTuning.debugReset();
  });

  group('the numbers', () {
    test('untouched, they are exactly the built-in look', () async {
      await FrameTuning.load();
      expect(FrameTuning.isDefault, isTrue);
      for (final knob in FrameTuning.knobs) {
        expect(FrameTuning.of(knob.id), knob.normal);
      }
    });

    test('a change is remembered', () async {
      await FrameTuning.set('top', 12);
      FrameTuning.debugReset();

      await FrameTuning.load();
      expect(FrameTuning.of('top'), 12);
      expect(FrameTuning.isDefault, isFalse);
    });

    test('a value beyond the dial is brought back inside it', () async {
      // A border four hundred pixels off the page is not one anyone can find
      // again to fix — including a value written by an older build.
      await FrameTuning.set('top', 4000);
      expect(FrameTuning.of('top'),
          FrameTuning.knobs.firstWhere((k) => k.id == 'top').max);

      SharedPreferences.setMockInitialValues({'@noor_frame_side': -900.0});
      await FrameTuning.load();
      expect(FrameTuning.of('side'),
          FrameTuning.knobs.firstWhere((k) => k.id == 'side').min);
    });

    test('resetting is a real return, not a second guess', () async {
      await FrameTuning.set('top', 20);
      await FrameTuning.set('scale', 1.6);
      await FrameTuning.reset();

      expect(FrameTuning.isDefault, isTrue);
      // And it survives: the stored values are gone, not merely overwritten
      // in memory.
      await FrameTuning.load();
      expect(FrameTuning.isDefault, isTrue);
    });

    test('the scale is a multiplier, so its normal is one and never zero', () {
      final scale = FrameTuning.knobs.firstWhere((k) => k.id == 'scale');
      expect(scale.normal, 1);
      expect(scale.min, greaterThan(0),
          reason: 'a scale of zero would erase the border with no way back');
    });

    test('every knob is adjustable in both directions from its normal', () {
      for (final knob in FrameTuning.knobs) {
        expect(knob.min, lessThan(knob.normal), reason: knob.id);
        expect(knob.max, greaterThan(knob.normal), reason: knob.id);
      }
    });

    test('the settings can be read out as one line', () async {
      await FrameTuning.set('top', 5);
      expect(FrameTuning.asText(), contains('top=5.0'));
    });
  });

  group('the panel', () {
    testWidgets('offers one slider per number', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: FrameTuningPanel()),
        ),
      ));
      await tester.pump();

      expect(find.byType(Slider), findsNWidgets(FrameTuning.knobs.length));
      for (final knob in FrameTuning.knobs) {
        expect(find.text(knob.label), findsOneWidget);
      }
    });

    testWidgets('the way back appears only once something has moved',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: FrameTuningPanel()),
        ),
      ));
      await tester.pump();
      expect(find.text('إعادة الضبط'), findsNothing);

      await FrameTuning.set('bottom', 10);
      await tester.pump();
      expect(find.text('إعادة الضبط'), findsOneWidget);

      await tester.tap(find.text('إعادة الضبط'));
      await tester.pump();
      await tester.pump();
      expect(find.text('إعادة الضبط'), findsNothing);
      expect(FrameTuning.isDefault, isTrue);
    });
  });

  group('the page listens', () {
    Widget sheet() => MaterialApp(
          home: Scaffold(
            body: MushafPageSheet(
              page: const MushafPage(
                number: 1,
                juz: 1,
                runs: [AyahRun(surah: 1, first: 1, last: 7)],
              ),
              surahInfo: (n) => const SurahInfo(
                number: 1,
                name: 'الفاتحة',
                nameEn: 'Al-Faatiha',
                ayahCount: 7,
                type: 'مكية',
              ),
              selected: null,
              onAyahTapped: (_) {},
              onBackgroundTapped: () {},
            ),
          ),
        );

    testWidgets('dragging "من فوق" moves the page down', (tester) async {
      await tester.pumpWidget(sheet());
      await tester.pump();

      final before = tester
          .widget<Padding>(find.byKey(const Key('mushaf-page-inset')))
          .padding
          .resolve(TextDirection.rtl)
          .top;

      await FrameTuning.set('top', 30);
      await tester.pump();

      final after = tester
          .widget<Padding>(find.byKey(const Key('mushaf-page-inset')))
          .padding
          .resolve(TextDirection.rtl)
          .top;

      expect(after - before, closeTo(30, 0.01),
          reason: 'the knob has to reach the page, not only the panel');
    });

    testWidgets('the page already clears both bars', (tester) async {
      await tester.pumpWidget(sheet());
      await tester.pump();

      final inset = tester
          .widget<Padding>(find.byKey(const Key('mushaf-page-inset')))
          .padding
          .resolve(TextDirection.rtl);

      // Each bar covered the border by the difference between its own height
      // and where the border begins — 32 above, 18 below. The page gives up
      // that much at each end on its own, so the sliders are for taste rather
      // than for undoing a fault.
      expect(inset.top, greaterThanOrEqualTo(32),
          reason: 'the border has to come out from under the top bar');
      expect(inset.bottom, greaterThanOrEqualTo(18),
          reason: 'and from under the bottom bar');
    });

    testWidgets('"من تحت" still moves the page from there', (tester) async {
      await tester.pumpWidget(sheet());
      await tester.pump();

      double bottom() => tester
          .widget<Padding>(find.byKey(const Key('mushaf-page-inset')))
          .padding
          .resolve(TextDirection.rtl)
          .bottom;

      final before = bottom();
      await FrameTuning.set('bottom', -18);
      await tester.pump();
      expect(bottom(), closeTo(before - 18, 0.01),
          reason: 'the slider is an offset from the built-in clearance');
    });

    testWidgets('dragging "الجانبان" pulls the ornament in from the sides',
        (tester) async {
      await tester.pumpWidget(sheet());
      await tester.pump();

      final before =
          tester.getRect(find.byKey(const Key('mushaf-frame-paint'))).left;

      await FrameTuning.set('side', 25);
      await tester.pump();

      final after =
          tester.getRect(find.byKey(const Key('mushaf-frame-paint'))).left;

      expect(after, greaterThan(before),
          reason: 'the flanks were hanging off the page; this brings them in');
    });
  });
}
