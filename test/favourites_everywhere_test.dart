import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/screens/favorites_screen.dart';
import 'package:salahulddin_azkar/data/adhkar_data.dart';
import 'package:salahulddin_azkar/data/hisn_data.dart';
import 'package:salahulddin_azkar/services/favourites.dart';
import 'package:salahulddin_azkar/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The star used to belong to the seven categorised sets alone, so the 132
/// chapters that are the bulk of the section — and the Umrah duas drawn from
/// them — could be read but never kept. These hold the two sources together.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a dhikr from Hisn can be kept, and comes back with its chapter',
      () async {
    final chapters = await HisnService.chapters();
    final chapter = chapters.firstWhere((c) => c.id == 104);
    final dhikr = chapter.items.first;

    await StorageService.toggleFavorite(
        Favourites.hisnId(chapter.id, dhikr.number));

    final entries = await Favourites.resolve();
    expect(entries.length, 1);
    expect(entries.single.text, dhikr.text);
    expect(entries.single.origin, chapter.title);
    expect(entries.single.hisn, isNotNull);
  });

  test('the adhkar that always had a star still resolve unchanged', () async {
    final dhikr = adhkar.firstWhere((d) => d.categoryId == 'morning');
    await StorageService.toggleFavorite(dhikr.id);

    final entries = await Favourites.resolve();
    expect(entries.single.dhikr?.id, dhikr.id);
    expect(entries.single.origin, 'أذكار الصباح',
        reason: 'a favourite should say which set it came from');
  });

  test('both sources sit in one list, in the order they were starred',
      () async {
    final chapters = await HisnService.chapters();
    final hisn = chapters.first;
    final dhikr = adhkar.firstWhere((d) => d.categoryId == 'evening');

    await StorageService.toggleFavorite(dhikr.id);
    await StorageService.toggleFavorite(
        Favourites.hisnId(hisn.id, hisn.items.first.number));

    final entries = await Favourites.resolve();
    expect(entries.map((e) => e.dhikr != null), [true, false]);
  });

  test('an id that no longer resolves is dropped, not shown blank', () async {
    // Written by a newer build, or arrived truncated from another device.
    for (final bad in ['hisn/9999/1', 'hisn/nope', 'hisn/104/9999', 'gone-3']) {
      await StorageService.toggleFavorite(bad);
    }
    expect(await Favourites.resolve(), isEmpty);
  });

  test('unstarring removes it from the list', () async {
    final chapters = await HisnService.chapters();
    final id = Favourites.hisnId(chapters.first.id, chapters.first.items.first.number);

    await StorageService.toggleFavorite(id);
    expect(await Favourites.resolve(), hasLength(1));

    await StorageService.toggleFavorite(id);
    expect(await Favourites.resolve(), isEmpty);
  });

  test('a Hisn id is not mistaken for a categorised one', () {
    expect(Favourites.isHisn(Favourites.hisnId(3, 1)), isTrue);
    expect(Favourites.isHisn('morning-6'), isFalse);
  });

  testWidgets('the tab shows a kept dhikr from Hisn, not only from a category',
      (tester) async {
    final chapters = await HisnService.chapters();
    final chapter = chapters.firstWhere((c) => c.items.first.text.length < 90);
    await StorageService.toggleFavorite(
        Favourites.hisnId(chapter.id, chapter.items.first.number));

    await tester.pumpWidget(const MaterialApp(home: FavoritesScreen()));
    await tester.pump();

    expect(find.text(chapter.items.first.text), findsOneWidget);
    expect(find.text(chapter.title), findsOneWidget,
        reason: 'a kept dhikr should say which chapter it came from');
  });
}
