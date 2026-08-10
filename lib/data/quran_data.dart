import 'dart:convert';
import 'package:flutter/services.dart';

class SurahInfo {
  final int number;
  final String name;
  final String nameEn;
  final int ayahCount;
  final String type; // مكية / مدنية

  const SurahInfo({
    required this.number,
    required this.name,
    required this.nameEn,
    required this.ayahCount,
    required this.type,
  });

  factory SurahInfo.fromJson(Map<String, dynamic> j) => SurahInfo(
        number: j['n'],
        name: j['name'],
        nameEn: j['nameEn'],
        ayahCount: j['ayahs'],
        type: j['type'],
      );

  /// Al-Fatiha counts the Basmala as its first ayah, and At-Tawbah has none,
  /// so only the other 112 surahs show it as a header.
  bool get hasBasmala => number != 1 && number != 9;
}

class Ayah {
  final int number;
  final String text;
  final bool isSajda;

  const Ayah({required this.number, required this.text, required this.isSajda});

  factory Ayah.fromJson(Map<String, dynamic> j) =>
      Ayah(number: j['n'], text: j['t'], isSajda: j['s'] == 1);
}

class Surah {
  final int number;
  final String name;
  final List<Ayah> ayahs;

  const Surah({required this.number, required this.name, required this.ayahs});
}

/// A contiguous stretch of one surah sitting on a Mushaf page.
class AyahRun {
  final int surah;
  final int first;
  final int last;

  const AyahRun({required this.surah, required this.first, required this.last});

  factory AyahRun.fromJson(Map<String, dynamic> j) =>
      AyahRun(surah: j['s'], first: j['f'], last: j['l']);

  /// True when this run opens the surah, so the page shows its header.
  bool get startsSurah => first == 1;
}

/// One of the 604 pages of the Madinah Mushaf.
class MushafPage {
  final int number;
  final int juz;
  final List<AyahRun> runs;

  const MushafPage({
    required this.number,
    required this.juz,
    required this.runs,
  });

  factory MushafPage.fromJson(Map<String, dynamic> j) => MushafPage(
        number: j['p'],
        juz: j['j'],
        runs: (j['r'] as List)
            .map((e) => AyahRun.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class QuranService {
  static const pageCount = 604;

  static List<SurahInfo>? _index;
  static List<MushafPage>? _pages;
  static String _basmala = '';
  static final Map<int, Surah> _cache = {};

  /// The Basmala exactly as the bundled edition spells it. It ships inside
  /// index.json instead of being hardcoded, because hand-typed Arabic does not
  /// reliably round-trip to the same code points as the source text.
  /// Empty until [index] or [surah] has run.
  static String get basmala => _basmala;

  /// The 114 surahs. Loaded once and kept in memory — the index is tiny.
  static Future<List<SurahInfo>> index() async {
    final cached = _index;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/quran/index.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    _basmala = j['basmala'] as String;
    return _index = (j['surahs'] as List)
        .map((e) => SurahInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Full text of one surah, loaded on demand and cached.
  static Future<Surah> surah(int number) async {
    await index(); // also guarantees [basmala] is populated for the reader
    final cached = _cache[number];
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/quran/surah_$number.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final s = Surah(
      number: j['n'],
      name: j['name'],
      ayahs: (j['ayahs'] as List)
          .map((e) => Ayah.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    _cache[number] = s;
    return s;
  }

  /// The Mushaf page index, loaded once (28 KB).
  static Future<List<MushafPage>> pages() async {
    final cached = _pages;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString('assets/quran/pages.json');
    return _pages = (jsonDecode(raw) as List)
        .map((e) => MushafPage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The page a surah opens on, for jumping from the surah list.
  static Future<int> pageOfSurah(int surah) async {
    for (final page in await pages()) {
      for (final run in page.runs) {
        if (run.surah == surah && run.startsSurah) return page.number;
      }
    }
    return 1;
  }

  /// Converts 25 -> ٢٥ for the ayah-number ornament.
  static String toArabicDigits(int n) {
    const zero = 0x0660; // ARABIC-INDIC DIGIT ZERO
    return String.fromCharCodes(
      n.toString().codeUnits.map((c) => zero + (c - 0x30)),
    );
  }
}
