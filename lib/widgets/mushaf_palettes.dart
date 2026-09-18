import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';

/// The paper a page is printed on, and the colour of everything drawn over it.
///
/// The page images are black text on a transparent ground, which is what makes
/// this possible at all: the same image sits on cream or on near-black. Dark
/// papers invert the text rather than tinting it, because black ink on a dark
/// sheet is not dim — it is gone.
enum MushafPalette {
  cream('cream', Color(0xFFF7F1E1), AppColors.gold, false),
  ivory('ivory', Color(0xFFFDFBF4), Color(0xFF9A7B25), false),
  sepia('sepia', Color(0xFFEFE0C4), Color(0xFF8B5E24), false),
  mint('mint', Color(0xFFE6F0E2), Color(0xFF2F6B3A), false),
  azure('azure', Color(0xFFE4ECF5), Color(0xFF23507F), false),
  slate('slate', Color(0xFF23262B), Color(0xFFD4A843), true),
  night('night', Color(0xFF11131A), Color(0xFFC8A24C), true),
  black('black', Color(0xFF000000), Color(0xFFB8860B), true);

  const MushafPalette(this.id, this.paper, this.ink, this.invert);

  final String id;

  /// Shown in the picker.
  String get label => switch (this) {
    MushafPalette.cream => t('mushaf.paletteCream'),
    MushafPalette.ivory => t('mushaf.paletteIvory'),
    MushafPalette.sepia => t('mushaf.paletteSepia'),
    MushafPalette.mint => t('mushaf.paletteMint'),
    MushafPalette.azure => t('mushaf.paletteAzure'),
    MushafPalette.slate => t('mushaf.paletteSlate'),
    MushafPalette.night => t('mushaf.paletteNight'),
    MushafPalette.black => t('mushaf.paletteBlack'),
  };

  /// The page background.
  final Color paper;

  /// Frame, ayah numbers, and anything else drawn on the page.
  final Color ink;

  /// Whether the printed text has to be inverted to stay legible.
  final bool invert;

  /// Text drawn by the app — the fallback rendering, page numbers — has to
  /// answer the paper, not the theme.
  Color get onPaper =>
      invert ? const Color(0xFFE8E2D4) : const Color(0xFF1A1408);

  Color get onPaperMuted =>
      invert ? const Color(0xFF9A937F) : const Color(0xFF8A7C5C);

  static MushafPalette byId(String? id) =>
      values.firstWhere((p) => p.id == id, orElse: () => cream);
}

/// The reader's chosen paper, remembered between runs.
class MushafPalettes {
  static const _key = '@noor_mushaf_palette';

  static final current = ValueNotifier<MushafPalette>(MushafPalette.cream);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      current.value = MushafPalette.byId(prefs.getString(_key));
    } catch (_) {
      // Cream is a perfectly good page.
    }
  }

  static Future<void> choose(MushafPalette palette) async {
    current.value = palette;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, palette.id);
    } catch (_) {
      // The choice still applies to this session.
    }
  }
}

/// Turns the printed page — black on transparent — into light text for a dark
/// paper. Inverting keeps the letterforms; tinting them would not, because
/// there is no colour dark enough to read on near-black.
class InvertedInk extends StatelessWidget {
  final bool active;
  final Widget child;

  const InvertedInk({super.key, required this.active, required this.child});

  static const _invert = ColorFilter.matrix(<double>[
    -1, 0, 0, 0, 255, //
    0, -1, 0, 0, 255, //
    0, 0, -1, 0, 255, //
    0, 0, 0, 1, 0, //
  ]);

  @override
  Widget build(BuildContext context) =>
      active ? ColorFiltered(colorFilter: _invert, child: child) : child;
}
