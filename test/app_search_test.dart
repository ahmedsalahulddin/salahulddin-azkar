import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/screens/search_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A search that only finds text spelled exactly as stored is a search for
/// people who already know where things are. This one folds Arabic the way the
/// Mushaf search does, so half a word typed plainly still lands.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a single letter finds nothing — that is not a query', () {
    expect(AppSearch.run('ا'), isEmpty);
    expect(AppSearch.run(''), isEmpty);
    expect(AppSearch.run('   '), isEmpty);
  });

  test('part of a word finds the whole', () {
    expect(AppSearch.run('حفظ').map((h) => h.title), contains('اختبار الحفظ'));
    expect(AppSearch.run('إذاع').map((h) => h.title), contains('الإذاعة'));
  });

  test('typed plainly, without hamza, it still lands', () {
    // "الإذاعة" carries a hamza the reader will not type.
    final plain = AppSearch.run('اذاع').map((h) => h.title);
    expect(plain, contains('الإذاعة'));
  });

  test('every hit says which section it came from', () {
    for (final hit in AppSearch.run('قرآن')) {
      expect(hit.section.trim(), isNotEmpty);
      expect(hit.title.trim(), isNotEmpty);
    }
  });

  test('it reaches past the shelves into the content', () async {
    // Lessons, books and cards are searched too, not just the home furniture.
    expect(AppSearch.run('أركان').map((h) => h.section), contains('الدروس'));
    expect(AppSearch.run('البخاري').map((h) => h.section),
        contains('الكتب والأحاديث'));
    expect(AppSearch.run('عيد').map((h) => h.section),
        contains('كروت المعايدة'));
  });

  test('surah names are found through the loaded index', () async {
    final hits = await AppSearch.loaded('اخلاص');
    // Folded, not literal: the stored name carries the Mushaf's diacritics,
    // and comparing raw Arabic is the hazard this whole search exists to
    // spare the reader.
    expect(
        hits.map((h) => QuranService.searchKey(h.title)),
        contains(QuranService.searchKey('سورة الإخلاص')));
    expect(hits.first.section, 'القرآن الكريم');
  });

  testWidgets('a hit opens what it names, not a blank screen', (tester) async {
    // The first version returned a widget per hit, and most of them returned
    // the wrong screen — or an empty one. A result that lies about where it
    // leads is worse than no result.
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox.shrink();
      }),
    ));

    final hits = [...AppSearch.run('اذكار'), ...await AppSearch.loaded('اخلاص')];
    expect(hits, isNotEmpty);

    for (final hit in hits.take(4)) {
      hit.open(ctx);
      // Fixed pumps, not pumpAndSettle: several destinations show a spinner
      // while they load, and a spinner never settles.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull,
          reason: '${hit.title} threw on the way to its screen');
      // A real screen arrived — the placeholder had no Scaffold of its own.
      expect(find.byType(Scaffold), findsWidgets,
          reason: '${hit.title} led nowhere');

      Navigator.of(ctx).popUntil((r) => r.isFirst);
      await tester.pump(const Duration(milliseconds: 400));
    }
  });

  test('a word in nothing finds nothing', () async {
    expect(AppSearch.run('زقزقة'), isEmpty);
    expect(await AppSearch.loaded('زقزقة'), isEmpty);
  });
}
