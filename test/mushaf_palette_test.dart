import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/widgets/mushaf_palettes.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The page images are black text on a transparent ground, which is what lets
/// one image sit on any paper — and also what makes a dark paper dangerous:
/// black ink on near-black is not dim, it is gone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Rough perceived lightness, 0 (black) to 1 (white).
  double lightness(Color c) =>
      (0.299 * c.r + 0.587 * c.g + 0.114 * c.b);

  test('ids and labels are unique — the picker has to tell them apart', () {
    expect(MushafPalette.values.map((p) => p.id).toSet().length,
        MushafPalette.values.length);
    expect(MushafPalette.values.map((p) => p.label).toSet().length,
        MushafPalette.values.length);
  });

  test('an unknown id falls back to the plain cream page', () {
    expect(MushafPalette.byId('written-by-a-later-build'), MushafPalette.cream);
    expect(MushafPalette.byId(null), MushafPalette.cream);
    for (final p in MushafPalette.values) {
      expect(MushafPalette.byId(p.id), p);
    }
  });

  test('every dark paper inverts its ink, and no light one does', () {
    for (final p in MushafPalette.values) {
      final dark = lightness(p.paper) < 0.5;
      expect(p.invert, dark,
          reason: '${p.label} is ${dark ? 'dark' : 'light'} but '
              'invert is ${p.invert}');
    }
  });

  test('the app-drawn text always contrasts with its paper', () {
    for (final p in MushafPalette.values) {
      final gap = (lightness(p.paper) - lightness(p.onPaper)).abs();
      expect(gap, greaterThan(0.4),
          reason: '${p.label} draws text too close to its own paper');
      // Muted text may be quieter, but still has to be readable.
      expect((lightness(p.paper) - lightness(p.onPaperMuted)).abs(),
          greaterThan(0.15),
          reason: '${p.label} muted text disappears');
    }
  });

  test('the ornament colour is visible against the paper', () {
    for (final p in MushafPalette.values) {
      expect((lightness(p.paper) - lightness(p.ink)).abs(), greaterThan(0.15),
          reason: '${p.label} would draw an invisible frame');
    }
  });

  test('a chosen paper comes back on the next run', () async {
    await MushafPalettes.choose(MushafPalette.night);
    expect(MushafPalettes.current.value, MushafPalette.night);

    MushafPalettes.current.value = MushafPalette.cream;
    await MushafPalettes.load();
    expect(MushafPalettes.current.value, MushafPalette.night);
  });

  testWidgets('the filter is applied only where the paper needs it',
      (tester) async {
    for (final active in [true, false]) {
      await tester.pumpWidget(MaterialApp(
        home: InvertedInk(active: active, child: const Text('نص')),
      ));
      expect(find.byType(ColorFiltered), active ? findsOneWidget : findsNothing);
    }
  });
}
