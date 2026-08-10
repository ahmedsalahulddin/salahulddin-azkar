import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/adhkar_data.dart';
import 'package:salahulddin_azkar/screens/favorites_screen.dart';
import 'package:salahulddin_azkar/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('toggling a favourite adds it, toggling again removes it', () async {
    final id = adhkar.first.id;

    expect(await StorageService.toggleFavorite(id), isTrue);
    expect(await StorageService.isFavorite(id), isTrue);
    expect(await StorageService.getFavorites(), contains(id));

    expect(await StorageService.toggleFavorite(id), isFalse);
    expect(await StorageService.isFavorite(id), isFalse);
    expect(await StorageService.getFavorites(), isNot(contains(id)));
  });

  test('every change announces itself', () async {
    final before = StorageService.favouritesRevision.value;

    await StorageService.toggleFavorite(adhkar.first.id);
    expect(StorageService.favouritesRevision.value, before + 1);

    await StorageService.toggleFavorite(adhkar.first.id);
    expect(StorageService.favouritesRevision.value, before + 2);
  });

  testWidgets('the favourites tab picks up a star tapped on another screen',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // The screen is built while nothing is starred — as happens at launch.
    await tester.pumpWidget(const MaterialApp(home: FavoritesScreen()));
    await tester.pump();
    expect(find.text('لا توجد أذكار محفوظة'), findsOneWidget);

    // A star is tapped elsewhere. The screen is never rebuilt by navigation,
    // exactly as inside the app's IndexedStack.
    final dhikr = adhkar.first;
    await StorageService.toggleFavorite(dhikr.id);
    await tester.pump();
    await tester.pump();

    expect(find.text('لا توجد أذكار محفوظة'), findsNothing);
    expect(find.textContaining(dhikr.text.substring(0, 20)), findsWidgets);

    // Un-starring it empties the list again.
    await StorageService.toggleFavorite(dhikr.id);
    await tester.pump();
    await tester.pump();
    expect(find.text('لا توجد أذكار محفوظة'), findsOneWidget);
  });
}
