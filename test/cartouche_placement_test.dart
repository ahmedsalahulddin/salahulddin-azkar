import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/screens/mushaf/page_sheet.dart';
import 'package:salahulddin_azkar/widgets/frame_tuning.dart';
import 'package:salahulddin_azkar/widgets/mushaf_chrome.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where the three labels sit, in pixels, measured rather than assumed.
///
/// Asked for by eye and to the pixel — the surah and the juz two up, their
/// writing two up inside them again, the page number one down. Nothing about
/// that survives a refactor unless it is written down as a number somebody
/// can check.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FrameTuning.debugReset();
    MushafChrome.debugSet(top: 90, bottom: 70);
  });

  Widget sheet() => MaterialApp(
        home: Scaffold(
          body: MushafPageSheet(
            page: const MushafPage(
              number: 3,
              juz: 1,
              runs: [AyahRun(surah: 2, first: 1, last: 5)],
            ),
            surahInfo: (n) => const SurahInfo(
              number: 2,
              name: 'البقرة',
              nameEn: 'Al-Baqara',
              ayahCount: 286,
              type: 'مدنية',
            ),
            selected: null,
            onAyahTapped: (_) {},
            onBackgroundTapped: () {},
          ),
        ),
      );

  testWidgets('the writing rides above the middle of its own layout box',
      (tester) async {
    // Every label is lifted, because the line box centres and the ink is what
    // is read: this face reserves room above each glyph for marks that a page
    // number and a juz number never carry, so an untouched label sits on the
    // floor of its cartouche. How far each is lifted was measured off a
    // rendered page — see the constants in page_sheet.dart — and this only
    // holds that the lift is still applied at all.
    await tester.pumpWidget(sheet());
    await tester.pump();

    for (final label in ['البقرة', 'الجزء ١', '٣']) {
      final moved = tester.widget<Transform>(find.ancestor(
        of: find.text(label),
        matching: find.byType(Transform),
      ).first);
      expect(moved.transform.getTranslation().y, lessThan(-4),
          reason: '$label is no longer being lifted inside its cartouche');
    }
  });

  testWidgets('the header pair sit on one line', (tester) async {
    // The boxes, not the writing. The two labels are lifted by slightly
    // different amounts inside their cartouches — measured separately,
    // because a name carrying diacritics and the words "الجزء ١" do not put
    // their ink in the same place — so their text no longer shares an exact
    // line and is not meant to. Their cartouches do.
    await tester.pumpWidget(sheet());
    await tester.pump();

    final surah = tester.getRect(find.byKey(const Key('mushaf-cartouche-surah')));
    final juz = tester.getRect(find.byKey(const Key('mushaf-cartouche-juz')));
    expect(surah.top, closeTo(juz.top, 0.01));
    expect(surah.height, closeTo(juz.height, 0.01));
  });

  testWidgets('each cartouche sits exactly where it was placed',
      (tester) async {
    // Written down because it was set by eye and to the pixel, and by eye is
    // exactly what a later change cannot re-derive: move all three by three
    // pixels and, without a number here, nothing anywhere would say so.
    await tester.pumpWidget(sheet());
    await tester.pump();

    final border = tester.getRect(find.byKey(const Key('mushaf-frame-box')));

    for (final label in ['surah', 'juz']) {
      final box = tester.getRect(find.byKey(Key('mushaf-cartouche-$label')));
      expect(box.center.dy - border.top, closeTo(35.5, 0.01),
          reason: '$label sits below the head of the border by this much');
    }
    final number =
        tester.getRect(find.byKey(const Key('mushaf-cartouche-number')));
    expect(border.bottom - number.center.dy, closeTo(28.5, 0.01),
        reason: 'the page number sits above the foot of the border by this '
            'much');
  });
}
