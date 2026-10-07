import 'dart:convert';

import 'package:flutter/services.dart';

/// Per-ayah notes bundled with the app, each from one classical book, kept
/// per surah in assets/{kind}/{surah}.json as {ayah: text}. Ayat the book
/// says nothing about have no entry.
enum AyahNoteKind {
  /// «أسباب نزول القرآن» لأبي الحسن الواحدي (ت ٤٦٨هـ).
  asbab('asbab', 'أسباب نزول القرآن', 'أبو الحسن الواحدي'),

  /// «التبيان في إعراب القرآن» لأبي البقاء العكبري (ت ٦١٦هـ).
  irab('irab', 'التبيان في إعراب القرآن', 'أبو البقاء العكبري');

  const AyahNoteKind(this.folder, this.book, this.author);

  final String folder;
  final String book;
  final String author;
}

class AyahNotesService {
  static final Map<String, Map<int, String>> _cache = {};

  static Future<String?> forAyah(AyahNoteKind kind, int surah, int ayah) async {
    final key = '${kind.folder}/$surah';
    final bySurah = _cache[key] ??= await _load(kind, surah);
    return bySurah[ayah];
  }

  static Future<Map<int, String>> _load(AyahNoteKind kind, int surah) async {
    try {
      final raw = await rootBundle.loadString(
        'assets/${kind.folder}/$surah.json',
      );
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return {for (final e in map.entries) int.parse(e.key): e.value as String};
    } catch (_) {
      return const {};
    }
  }
}
