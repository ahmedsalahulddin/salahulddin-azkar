import 'dart:convert';
import 'package:flutter/services.dart';
import '../services/app_locale.dart';
import 'hisn_translations/bn.dart';
import 'hisn_translations/fr.dart';
import 'hisn_translations/ha.dart';
import 'hisn_translations/hi.dart';
import 'hisn_translations/id.dart';
import 'hisn_translations/ms.dart';
import 'hisn_translations/tr.dart';
import 'hisn_translations/ur.dart';

/// Machine translations of Hisn al-Muslim, keyed by language then by a
/// "chapterId:number" key — [HisnDhikr.number] alone is only unique within
/// its chapter, so the chapter id disambiguates it. Unlike
/// [HisnDhikr.english] — the publisher's own translation from the
/// hisnmuslim.com API — these are Claude AI renderings, not a scholarly or
/// human-reviewed translation. The UI discloses this next to every one.
final Map<String, Map<String, String>> hisnTranslations = {
  'bn': bnHisnTranslations,
  'fr': frHisnTranslations,
  'ha': haHisnTranslations,
  'hi': hiHisnTranslations,
  'id': idHisnTranslations,
  'ms': msHisnTranslations,
  'tr': trHisnTranslations,
  'ur': urHisnTranslations,
};

/// A dhikr's translation in [lang], or null if that language doesn't cover
/// this dhikr (or [lang] is 'en', which lives on [HisnDhikr.english]
/// instead).
String? hisnTranslationFor(int chapterId, int dhikrNumber, String lang) =>
    hisnTranslations[lang]?['$chapterId:$dhikrNumber'];

/// Every available machine translation of one dhikr, keyed by language
/// code — what [DhikrText.moreTranslations] expects.
Map<String, String> hisnTranslationsFor(int chapterId, int dhikrNumber) {
  final key = '$chapterId:$dhikrNumber';
  final out = <String, String>{};
  for (final entry in hisnTranslations.entries) {
    final text = entry.value[key];
    if (text != null) out[entry.key] = text;
  }
  return out;
}

/// Machine-translation credit shown next to every non-English rendering.
const hisnTranslator = 'Claude AI';

/// Language codes with a machine translation, in menu order — the same set
/// covered by the Islamic Stories feature.
const supportedHisnLanguages = <(String code, String name)>[
  ('fr', 'Français'),
  ('ur', 'اردو'),
  ('id', 'Indonesia'),
  ('ms', 'Bahasa Melayu'),
  ('hi', 'हिन्दी'),
  ('tr', 'Türkçe'),
  ('bn', 'বাংলা'),
  ('ha', 'Hausa'),
];

class HisnDhikr {
  final int number;
  final String text;

  /// How many times the dhikr is said.
  final int repeat;

  /// Id of the published recitation, or null for the one dhikr the source
  /// ships without audio.
  final int? audioId;

  /// The publisher's own English translation, fetched from the same
  /// hisnmuslim.com API the audio is served from.
  final String? english;

  const HisnDhikr({
    required this.number,
    required this.text,
    required this.repeat,
    this.audioId,
    this.english,
  });

  factory HisnDhikr.fromJson(Map<String, dynamic> j) => HisnDhikr(
        number: j['n'],
        text: j['t'],
        repeat: j['r'] ?? 1,
        audioId: j['au'],
        english: (j['en'] as String?)?.isEmpty ?? true ? null : j['en'],
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
  final String? titleEn;
  final List<HisnDhikr> items;

  const HisnChapter({
    required this.id,
    required this.title,
    this.titleEn,
    required this.items,
  });

  factory HisnChapter.fromJson(Map<String, dynamic> j) => HisnChapter(
        id: j['id'],
        title: j['title'],
        titleEn: j['titleEn'],
        items: (j['items'] as List)
            .map((e) => HisnDhikr.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Arabic with the English chapter title in parentheses, once the reader
  /// has switched to English — same convention as every other card name.
  String get displayTitle {
    if (!AppLocale.isEn || titleEn == null) return title;
    return '$title ($titleEn)';
  }
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
