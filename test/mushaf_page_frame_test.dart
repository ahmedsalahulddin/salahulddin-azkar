import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/screens/mushaf_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The border belongs to the page, not to the screen: directly above the first
/// line and directly below the last, carrying the surah and juz above and the
/// page number below — the way a printed Mushaf does it.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpPage(WidgetTester tester, int page) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(home: MushafScreen(initialPage: page)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('the page carries its own header and footer', (tester) async {
    // Page 582 opens سورة النبأ in the thirtieth juz.
    await pumpPage(tester, 582);

    final pages = await QuranService.pages();
    final page = pages.firstWhere((p) => p.number == 582);
    final index = await QuranService.index();
    final surah =
        index.firstWhere((s) => s.number == page.runs.first.surah).name;

    expect(find.text(surah), findsWidgets, reason: 'no surah in the header');
    expect(find.text('الجزء ${QuranService.toArabicDigits(page.juz)}'),
        findsOneWidget);
    expect(find.text(QuranService.toArabicDigits(582)), findsWidgets,
        reason: 'no page number in the footer');
  });

  testWidgets('the page number sits in the middle of the bottom band',
      (tester) async {
    await pumpPage(tester, 582);

    final number = find.text(QuranService.toArabicDigits(582)).last;
    final centre = tester.getCenter(number);
    final screen = tester.getSize(find.byType(MushafScreen));

    expect(centre.dx, closeTo(screen.width / 2, 6),
        reason: 'the page number is not centred');
    // And in the lower half — it is a footer.
    expect(centre.dy, greaterThan(screen.height / 2));
  });

  testWidgets('the page fills the sheet it was given', (tester) async {
    // The sheet's Stack once handed the page loose constraints, so it sized
    // itself to the image's own thousand-odd pixels, laid out against a box
    // that was not the one on screen, and mapped every tap to the wrong ayah.
    // The action bar, which only lights up once an ayah is selected, went
    // dead with it.
    await pumpPage(tester, 582);

    final screen = tester.getSize(find.byType(MushafScreen));
    final pages = tester.widgetList<PageView>(find.byType(PageView));
    expect(pages, isNotEmpty);

    // Whatever the page renders as, it must not be wider than the phone.
    for (final box in tester.widgetList<SizedBox>(find.byType(SizedBox))) {
      final width = box.width;
      if (width != null && width.isFinite) {
        expect(width, lessThanOrEqualTo(screen.width + 1),
            reason: 'something inside the page is wider than the screen');
      }
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('the surah sits right of the juz, as on the printed page',
      (tester) async {
    await pumpPage(tester, 582);

    final pages = await QuranService.pages();
    final page = pages.firstWhere((p) => p.number == 582);
    final index = await QuranService.index();
    final surah =
        index.firstWhere((s) => s.number == page.runs.first.surah).name;

    final surahX = tester.getCenter(find.text(surah).last).dx;
    final juzX = tester
        .getCenter(find.text('الجزء ${QuranService.toArabicDigits(page.juz)}'))
        .dx;
    expect(surahX, greaterThan(juzX));
  });
}
