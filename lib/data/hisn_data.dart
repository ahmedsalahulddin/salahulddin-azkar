import 'dart:convert';
import 'package:flutter/services.dart';

class HisnDhikr {
  final int number;
  final String text;

  /// How many times the dhikr is said.
  final int repeat;

  /// Id of the published recitation, or null for the one dhikr the source
  /// ships without audio.
  final int? audioId;

  const HisnDhikr({
    required this.number,
    required this.text,
    required this.repeat,
    this.audioId,
  });

  factory HisnDhikr.fromJson(Map<String, dynamic> j) => HisnDhikr(
        number: j['n'],
        text: j['t'],
        repeat: j['r'] ?? 1,
        audioId: j['au'],
      );

  bool get hasAudio => audioId != null;

  /// Streamed rather than bundled: 267 recitations would far outweigh the
  /// text they belong to.
  String? get audioUrl =>
      audioId == null ? null : '${HisnService.audioHost}/$audioId.mp3';
}

class HisnChapter {
  final int id;
  final String title;
  final List<HisnDhikr> items;

  const HisnChapter({
    required this.id,
    required this.title,
    required this.items,
  });

  factory HisnChapter.fromJson(Map<String, dynamic> j) => HisnChapter(
        id: j['id'],
        title: j['title'],
        items: (j['items'] as List)
            .map((e) => HisnDhikr.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Hisn al-Muslim (حصن المسلم) by Sa'id bin Ali al-Qahtani — the compilation
/// most authenticated-adhkar collections are built on. Sourced from the
/// publisher's own developer API at hisnmuslim.com and bundled so the whole
/// section works offline.
class HisnService {
  static const title = 'صحيح الأذكار';
  static const attribution = 'حصن المسلم — سعيد بن علي القحطاني';

  /// The publisher's own recitations, served over HTTPS with open CORS so they
  /// play on the web build too.
  static const audioHost = 'https://www.hisnmuslim.com/audio/ar';

  static List<HisnChapter>? _chapters;

  static Future<List<HisnChapter>> chapters() async {
    final cached = _chapters;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/adhkar/hisn.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return _chapters = (j['chapters'] as List)
        .map((e) => HisnChapter.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<int> totalAdhkar() async {
    final list = await chapters();
    return list.fold<int>(0, (sum, c) => sum + c.items.length);
  }
}
