import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/home_shelves.dart';
import 'package:salahulddin_azkar/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The home screen is a set of shelves. Each names itself, keeps its most-used
/// card pinned where the thumb expects it, and lets the rest run off the side.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('the shelves themselves', () {
    test('in the order they were asked for', () {
      expect(buildShelves().map((s) => s.key).toList(),
          ['quran', 'adhkar', 'lessons', 'library', 'cards']);
    });

    test('the pinned card is the one asked for on each shelf', () {
      final shelves = {for (final s in buildShelves()) s.key: s};
      expect(shelves['adhkar']!.pinned.title, 'صحيح الأذكار');
      expect(shelves['quran']!.pinned.title, 'القرآن الكريم');
      // The lessons shelf leads with a lesson that exists rather than one
      // waiting on a channel.
      expect(shelves['lessons']!.pinned.title, 'أركان الإسلام');
      expect(shelves['cards']!.pinned.title, 'كروتي');
    });

    test('the pinned card is never repeated among the rest', () {
      for (final shelf in buildShelves()) {
        expect(shelf.rest.map((i) => i.title), isNot(contains(shelf.pinned.title)),
            reason: '${shelf.key} shows its pinned card twice');
      }
    });

    test('every shelf has something beside the pinned card to scroll', () {
      for (final shelf in buildShelves()) {
        expect(shelf.rest, isNotEmpty, reason: '${shelf.key} has nothing to scroll');
      }
    });

    test('the Quran shelf: the ways to read, then the ways to listen', () {
      final quran = buildShelves().firstWhere((s) => s.key == 'quran');
      expect([quran.pinned.title, ...quran.rest.map((i) => i.title)],
          ['القرآن الكريم', 'تلاوة وتدبّر', 'اختبار الحفظ', 'الإذاعة', 'الاستماع الدائم']);
    });

    test('the adhkar shelf gathers what used to be loose on the home screen',
        () {
      final adhkar = buildShelves().firstWhere((s) => s.key == 'adhkar');
      final titles = adhkar.rest.map((i) => i.title).toList();
      expect(titles, contains('أدعية العمرة'));
      expect(titles, contains('عداد التسبيح'));
      // Ten or so cards, which is what makes the row worth scrolling.
      expect(adhkar.rest.length, greaterThan(5));
    });
  });

  group('on screen', () {
    testWidgets('each shelf shows its name and its pinned card',
        (tester) async {
      await pumpHome(tester);

      for (final shelf in buildShelves()) {
        // Not exactly one: the Quran shelf's heading and the card that opens
        // the Mushaf carry the same name by design.
        expect(find.text(shelf.title), findsWidgets,
            reason: '${shelf.key} has no heading');
        expect(find.text(shelf.pinned.title), findsWidgets,
            reason: '${shelf.key} is missing its pinned card');
      }
    });

    testWidgets('the rest of each shelf scrolls sideways', (tester) async {
      await pumpHome(tester);

      // A horizontal list per shelf — that is what makes the row scrollable
      // rather than a fixed set of tiles.
      final rows = find.byWidgetPredicate((w) =>
          w is ListView && w.scrollDirection == Axis.horizontal);
      expect(rows, findsNWidgets(buildShelves().length));
    });

    testWidgets('a card far along the adhkar row can be scrolled to',
        (tester) async {
      await pumpHome(tester);

      // By shelf, not by position: the order has changed once already and
      // "the first row" quietly stopped meaning the adhkar.
      final adhkar = buildShelves().indexWhere((s) => s.key == 'adhkar');
      final row = find
          .byWidgetPredicate(
              (w) => w is ListView && w.scrollDirection == Axis.horizontal)
          .at(adhkar);
      // The tasbih sits at the end of the adhkar shelf.
      expect(find.text('عداد التسبيح'), findsNothing);
      await tester.drag(row, const Offset(900, 0));
      await tester.pump();
      expect(find.text('عداد التسبيح'), findsOneWidget);
    });

    testWidgets('the pinned card stays put while its row scrolls',
        (tester) async {
      await pumpHome(tester);

      final before = tester.getTopLeft(find.text('صحيح الأذكار'));
      final adhkar = buildShelves().indexWhere((s) => s.key == 'adhkar');
      final row = find
          .byWidgetPredicate(
              (w) => w is ListView && w.scrollDirection == Axis.horizontal)
          .at(adhkar);
      await tester.drag(row, const Offset(600, 0));
      await tester.pump();

      expect(tester.getTopLeft(find.text('صحيح الأذكار')), before);
    });
  });
}
