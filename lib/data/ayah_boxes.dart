import 'dart:convert';
import 'package:flutter/services.dart';

/// Where one ayah sits on a Mushaf page. An ayah usually wraps across a few
/// lines, so it carries one rectangle per line it occupies.
class AyahBoxes {
  final int surah;
  final int ayah;

  /// Rectangles in the source image's pixel space (reference width 1024).
  final List<Rect> rects;

  const AyahBoxes({
    required this.surah,
    required this.ayah,
    required this.rects,
  });

  String get key => '$surah:$ayah';
}

/// Maps taps on the printed page to ayahs, and back again for highlighting.
///
/// Coordinates are stored against the width the source images are published at
/// and scaled at draw time, so they stay correct whatever size the page is
/// actually rendered at.
class AyahBoxService {
  static const referenceWidth = 1024.0;

  static Map<int, List<AyahBoxes>>? _byPage;

  static Future<Map<int, List<AyahBoxes>>> _load() async {
    final cached = _byPage;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/quran/ayah_boxes.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final pages = j['pages'] as Map<String, dynamic>;

    final result = <int, List<AyahBoxes>>{};
    pages.forEach((page, entries) {
      result[int.parse(page)] = (entries as List).map((e) {
        final m = e as Map<String, dynamic>;
        return AyahBoxes(
          surah: m['s'],
          ayah: m['a'],
          rects: (m['b'] as List).map((box) {
            final b = (box as List).cast<num>();
            return Rect.fromLTRB(
              b[0].toDouble(),
              b[1].toDouble(),
              b[2].toDouble(),
              b[3].toDouble(),
            );
          }).toList(),
        );
      }).toList();
    });

    return _byPage = result;
  }

  static Future<List<AyahBoxes>> forPage(int page) async =>
      (await _load())[page] ?? const [];

  /// The ayah under [point], given in source-image pixels, or null if the tap
  /// landed on a margin, a surah banner, or the page border.
  static AyahBoxes? hitTest(List<AyahBoxes> boxes, Offset point) {
    for (final entry in boxes) {
      for (final rect in entry.rects) {
        if (rect.contains(point)) return entry;
      }
    }
    return null;
  }
}
