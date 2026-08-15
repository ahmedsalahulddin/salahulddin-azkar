import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/adhkar_data.dart';
import 'package:salahulddin_azkar/screens/favorites_screen.dart';
import 'package:salahulddin_azkar/services/storage_service.dart';
import 'package:salahulddin_azkar/widgets/speak_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A list of twenty favourites played one recording at a time, each naming
/// its chapter before the words and repeating the short ones. Reading them
/// straight through is a different thing from playing one, and needs its own
/// control.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Tts.stop();
  });

  testWidgets('an empty list offers nothing to read', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FavoritesScreen()));
    await tester.pump();

    expect(find.text('اقرأ الكل'), findsNothing);
  });

  testWidgets('a kept dhikr brings the button with it', (tester) async {
    await StorageService.toggleFavorite(
        adhkar.firstWhere((d) => d.categoryId == 'morning').id);

    await tester.pumpWidget(const MaterialApp(home: FavoritesScreen()));
    await tester.pump();
    await tester.pump();

    expect(find.text('اقرأ الكل'), findsOneWidget);
  });

  testWidgets('while reading, the bar counts and offers stop and skip',
      (tester) async {
    await StorageService.toggleFavorite(adhkar.first.id);

    await tester.pumpWidget(const MaterialApp(home: FavoritesScreen()));
    await tester.pump();
    await tester.pump();

    // Standing in for the engine, which has no voice in a test — and which
    // must not be called from inside a widget test at all: awaiting a
    // platform channel here waits on a message loop the test clock does not
    // advance, and the test simply never ends.
    Tts.readingIndex.value = 0;
    await tester.pump();

    expect(find.textContaining('يقرأ'), findsOneWidget);
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    expect(find.byIcon(Icons.skip_next), findsOneWidget);
    expect(find.text('اقرأ الكل'), findsNothing);

    Tts.readingIndex.value = null;
    await tester.pump();
    expect(find.text('اقرأ الكل'), findsOneWidget);
  });

  test('reading a single passage ends a run that was going', () async {
    Tts.readingIndex.value = 3;
    // A speak button tapped mid-run. Two voices at once is noise, so the run
    // gives way rather than talking over it.
    await Tts.toggle('lesson-1', 'نص');
    expect(Tts.readingIndex.value, isNull);
    await Tts.stop();
  });

  test('an empty list is not a run', () async {
    await Tts.readAll(const []);
    expect(Tts.readingIndex.value, isNull);
  });

  test('stopping clears the run, and skipping outside one does nothing',
      () async {
    Tts.readingIndex.value = 2;
    await Tts.stop();
    expect(Tts.readingIndex.value, isNull);

    await Tts.skip(); // must not throw, and must not start anything
    expect(Tts.readingIndex.value, isNull);
  });
}
