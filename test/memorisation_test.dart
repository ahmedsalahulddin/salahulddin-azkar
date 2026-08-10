import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/screens/memorisation_test_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('difficulty levels hide progressively more of the ayah', () {
    expect(TestDifficulty.easy.hiddenWords, 1);
    expect(TestDifficulty.medium.hiddenWords, 3);
    // -1 stands for the whole ayah.
    expect(TestDifficulty.hard.hiddenWords, -1);
    expect(TestDifficulty.values.length, 3);
  });

  testWidgets('the drill hides the end of the ayah and reveals on demand',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final info = (await QuranService.index()).firstWhere((s) => s.number == 112);
    await tester
        .pumpWidget(MaterialApp(home: MemorisationTestScreen(info: info)));
    await tester.pump();
    await tester.pump();

    // Starts on ayah 1 of 4, nothing scored yet.
    expect(find.textContaining('الآية ١ من ٤'), findsOneWidget);
    expect(find.text('اكشف'), findsOneWidget);
    expect(find.text('تذكّرتها'), findsNothing);

    // Revealing swaps the prompt for the scoring buttons.
    await tester.tap(find.text('اكشف'));
    await tester.pump();
    expect(find.text('تذكّرتها'), findsOneWidget);
    expect(find.text('لم أتذكّر'), findsOneWidget);

    // Scoring advances to the next ayah and hides it again.
    await tester.tap(find.text('تذكّرتها'));
    await tester.pump();
    expect(find.textContaining('الآية ٢ من ٤'), findsOneWidget);
    expect(find.text('اكشف'), findsOneWidget);
  });

  testWidgets('finishing the surah reports a score', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final info = (await QuranService.index()).firstWhere((s) => s.number == 112);
    await tester
        .pumpWidget(MaterialApp(home: MemorisationTestScreen(info: info)));
    await tester.pump();
    await tester.pump();

    // Answer all four ayahs correctly.
    for (var i = 0; i < info.ayahCount; i++) {
      await tester.tap(find.text('اكشف'));
      await tester.pump();
      await tester.tap(find.text('تذكّرتها'));
      await tester.pump();
    }

    expect(find.text('100%'), findsOneWidget);
    expect(find.textContaining('تذكّرت ٤ من ٤'), findsOneWidget);
    expect(find.text('أعد الاختبار'), findsOneWidget);
  });
}
