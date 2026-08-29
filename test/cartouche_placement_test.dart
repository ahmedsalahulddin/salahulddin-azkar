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

  testWidgets('the writing sits above the middle of its own cartouche',
      (tester) async {
    await tester.pumpWidget(sheet());
    await tester.pump();

    for (final label in ['البقرة', 'الجزء ١', '٣']) {
      final text = tester.getRect(find.text(label));
      // The cartouche is the nearest Container above the text; its centre is
      // what the writing is meant to sit above.
      final box = tester.getRect(find.ancestor(
        of: find.text(label),
        matching: find.byType(Transform),
      ).first);

      expect(text.center.dy, lessThan(box.center.dy),
          reason: '$label should ride above the middle of its box');
    }
  });

  testWidgets('the header pair share a line', (tester) async {
    await tester.pumpWidget(sheet());
    await tester.pump();

    final surah = tester.getRect(find.text('البقرة'));
    final juz = tester.getRect(find.text('الجزء ١'));
    expect(surah.center.dy, closeTo(juz.center.dy, 0.01),
        reason: 'they sit on one line and must move together');
  });

  testWidgets('each label sits exactly where it was placed', (tester) async {
    // Measured, then written down. These were set by eye against the printed
    // page and to the pixel, and by eye is precisely what no later change can
    // re-derive: without a number here, a refactor that moved them all by
    // three would look like nothing had happened.
    await tester.pumpWidget(sheet());
    await tester.pump();

    final box = tester.getRect(find.byKey(const Key('mushaf-frame-box')));

    for (final label in ['البقرة', 'الجزء ١']) {
      expect(tester.getRect(find.text(label)).center.dy - box.top,
          closeTo(33.5, 0.01),
          reason: '$label sits below the top of the border by this much');
    }
    expect(box.bottom - tester.getRect(find.text('٣')).center.dy,
        closeTo(30.5, 0.01),
        reason: 'the page number sits above the foot of the border by this '
            'much');
  });
}
