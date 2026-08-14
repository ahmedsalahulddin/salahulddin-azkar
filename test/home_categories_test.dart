import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The home screen is four shelves now, not a grid of loose tiles. Each shelf
/// has to name what is on it — the point of the change was that "المكتبة" on
/// its own told the reader nothing about whether Bukhari was inside.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHome(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('four shelves, in the order they were asked for', (tester) async {
    await pumpHome(tester);

    const expected = ['الأذكار', 'القرآن الكريم', 'الدروس', 'الكتب والأحاديث'];
    for (final title in expected) {
      expect(find.text(title), findsOneWidget, reason: '$title is missing');
    }

    // Top to bottom, in that order.
    var previous = -1.0;
    for (final title in expected) {
      final y = tester.getTopLeft(find.text(title)).dy;
      expect(y, greaterThan(previous), reason: '$title is out of order');
      previous = y;
    }
  });

  testWidgets('each shelf names what is on it', (tester) async {
    await pumpHome(tester);

    // A reader looking for Hisn al-Muslim or Bukhari can see which shelf to
    // open without opening any of them.
    expect(find.textContaining('حصن المسلم'), findsOneWidget);
    expect(find.textContaining('اختبار الحفظ'), findsOneWidget);
    expect(find.textContaining('قصص الأنبياء'), findsOneWidget);
    expect(find.textContaining('البخاري'), findsOneWidget);
  });

  testWidgets('the loose tiles are gone from the top level', (tester) async {
    await pumpHome(tester);

    // Tasbih moved in with the adhkar; favourites has its own tab. Finding
    // either as a top-level card would mean the old grid came back.
    expect(find.text('عداد التسبيح'), findsNothing);
    expect(find.text('المفضلة'), findsNothing);
    expect(find.text('الوفيات'), findsNothing);
  });

  testWidgets('the prayer card still leads, above the shelves', (tester) async {
    await pumpHome(tester);

    final shelf = tester.getTopLeft(find.text('الأذكار')).dy;
    // The countdown sits inside the prayer card.
    expect(find.text('الأقسام'), findsOneWidget);
    expect(tester.getTopLeft(find.text('الأقسام')).dy, lessThan(shelf));
  });
}
