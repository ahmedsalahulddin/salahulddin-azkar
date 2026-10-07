import 'dart:convert';

import 'package:flutter/services.dart';

/// One unusual word of an ayah and what it means.
class GharibEntry {
  final String word;
  final String meaning;

  const GharibEntry(this.word, this.meaning);
}

/// Word meanings from «الميسر في غريب القرآن الكريم» by the King Fahd
/// Glorious Qur'an Printing Complex — the file the Complex offers to
/// developers (MuyassarGhareeb.docx), split per surah into
/// assets/gharib/{surah}.json as {ayah: [{w, m}]}. Ayat with no unusual word
/// have no entry.
class GharibService {
  static const source = 'الميسر في غريب القرآن الكريم';
  static const publisher = 'مجمع الملك فهد لطباعة المصحف الشريف';

  static final Map<int, Map<int, List<GharibEntry>>> _cache = {};

  static Future<List<GharibEntry>> forAyah(int surah, int ayah) async {
    final bySurah = _cache[surah] ??= await _load(surah);
    return bySurah[ayah] ?? const [];
  }

  static Future<Map<int, List<GharibEntry>>> _load(int surah) async {
    try {
      final raw = await rootBundle.loadString('assets/gharib/$surah.json');
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      return {
        for (final e in map.entries)
          int.parse(e.key): [
            for (final item in (e.value as List).cast<Map>())
              GharibEntry(item['w'] as String, item['m'] as String),
          ],
      };
    } catch (_) {
      return const {};
    }
  }
}
