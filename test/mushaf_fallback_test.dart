import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/widgets/mushaf_palettes.dart';

/// When the printed page cannot be fetched, the app sets the bundled text
/// itself — and that text is not covered by the inversion that saves the
/// printed image on a dark paper. It has to take its colours from the paper,
/// or a reader with no connection and a night page gets a blank sheet.
///
/// Building the screen to check this needs the image service, which reaches
/// for the network; reading the source is the cheap way to hold the rule.
void main() {
  late String source;

  setUpAll(() {
    source = File('lib/screens/mushaf/page_sheet.dart').readAsStringSync();
  });

  test('the fallback takes its colours from the chosen paper', () {
    for (final token in ['palette.onPaper', 'palette.ink']) {
      expect(source, contains(token),
          reason: 'the bundled text should be drawn in $token');
    }
  });

  test('no fixed ink is left in the page the app draws itself', () {
    // The two that were there: near-black ink and a cream surah header. Both
    // vanish on a dark paper.
    for (final fixed in ['0xFF1A1A1A', '0xFFE8DCC0', '0xFF6B5A2E', '0xFF9A7B2E']) {
      expect(source, isNot(contains(fixed)),
          reason: 'a colour fixed at $fixed cannot answer the paper');
    }
  });

  test('every paper it might be drawn on can carry text at all', () {
    double lightness(c) => 0.299 * c.r + 0.587 * c.g + 0.114 * c.b;

    for (final palette in MushafPalette.values) {
      expect((lightness(palette.paper) - lightness(palette.onPaper)).abs(),
          greaterThan(0.4),
          reason: '${palette.label} cannot show the fallback text');
      expect((lightness(palette.paper) - lightness(palette.ink)).abs(),
          greaterThan(0.15),
          reason: '${palette.label} cannot show the surah heading');
    }
  });
}
