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

/// An ayah that matched a search, with where it lives.
class AyahHit {
  final int surah;
  final String surahName;
  final int ayah;
  final String text;

  /// The text stripped of diacritics, so a plainly typed query can match it.
  final String key;

  const AyahHit({
    required this.surah,
    required this.surahName,
    required this.ayah,
    required this.text,
    required this.key,
  });
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

  /// One ayah matching a search, with enough context to jump to it.
  static List<AyahHit>? _searchIndex;

  /// Strips what a reader will not type: diacritics, the marks specific to the
  /// Mushaf, and the letter variants they will not distinguish. Searching for
  /// "الرحمن" has to find "ٱلرَّحۡمَٰن".
  static String searchKey(String text) {
    const marks = {
      0x0640, // tatweel
      0x0670, // superscript alef
    };
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (marks.contains(rune)) continue;
      // Harakat, tanween, Mushaf marks and Arabic Extended-A additions.
      if ((rune >= 0x0610 && rune <= 0x061A) ||
          (rune >= 0x064B && rune <= 0x065F) ||
          (rune >= 0x06D6 && rune <= 0x06ED) ||
          (rune >= 0x08D3 && rune <= 0x08FF)) {
        continue;
      }
      final char = String.fromCharCode(rune);
      buffer.write(switch (char) {
        'ٱ' || 'آ' || 'أ' || 'إ' => 'ا',
        'ى' => 'ي',
        'ؤ' => 'و',
        'ئ' => 'ي',
        'ة' => 'ه',
        'ء' => '',
        _ => char,
      });
    }
    return buffer.toString();
  }

  /// Every ayah, keyed for searching. Built once — 6236 ayahs is small enough
  /// to hold, and rebuilding it per keystroke would make search unusable.
  static Future<List<AyahHit>> _buildSearchIndex() async {
    final cached = _searchIndex;
    if (cached != null) return cached;

    final built = <AyahHit>[];
    for (final info in await index()) {
      final surah = await QuranService.surah(info.number);
      for (final ayah in surah.ayahs) {
        built.add(AyahHit(
          surah: info.number,
          surahName: info.name,
          ayah: ayah.number,
          text: ayah.text,
          key: searchKey(ayah.text),
        ));
      }
    }
    return _searchIndex = built;
  }

  /// Ayahs containing [query], in Mushaf order.
  static Future<List<AyahHit>> search(String query) async {
    final needle = searchKey(query.trim());
    if (needle.isEmpty) return const [];
    return (await _buildSearchIndex())
        .where((hit) => hit.key.contains(needle))
        .toList();
  }

  /// Total occurrences of [query], counting a verse more than once when it
  /// repeats the word.
  static Future<int> countOccurrences(String query) async {
    final needle = searchKey(query.trim());
    if (needle.isEmpty) return 0;
    var total = 0;
    for (final hit in await _buildSearchIndex()) {
      var from = 0;
      while (true) {
        final at = hit.key.indexOf(needle, from);
        if (at < 0) break;
        total++;
        from = at + needle.length;
      }
    }
    return total;
  }

  /// Whether [info] answers [query].
  ///
  /// The reader types plainly: no hamza, no madda, no ta marbuta, and usually
  /// without the article — "اخلاص" has to find "الإخلاص" and "عمران" has to
  /// find "آل عمران". Comparing the raw names finds neither, so both sides are
  /// folded through [searchKey] first.
  static bool surahMatches(SurahInfo info, String query) {
    final q = query.trim();
    if (q.isEmpty) return true;

    final needle = searchKey(q);
    if (needle.isNotEmpty && searchKey(info.name).contains(needle)) return true;
    if (info.nameEn.toLowerCase().contains(q.toLowerCase())) return true;

    // Readers type the surah number in whichever digits their keyboard gives.
    final digits = toWesternDigits(q);
    return digits.isNotEmpty && info.number.toString() == digits;
  }

  /// Turns ٢٥ into 25, leaving anything that is not a digit behind.
  static String toWesternDigits(String text) {
    const arabicZero = 0x0660;
    final buffer = StringBuffer();
    for (final rune in text.runes) {
      if (rune >= arabicZero && rune <= arabicZero + 9) {
        buffer.writeCharCode(0x30 + (rune - arabicZero));
      } else if (rune >= 0x30 && rune <= 0x39) {
        buffer.writeCharCode(rune);
      } else if (rune != 0x20) {
        return ''; // not a number at all
      }
    }
    return buffer.toString();
  }

  /// Converts 25 -> ٢٥ for the ayah-number ornament.
  static String toArabicDigits(int n) {
    const zero = 0x0660; // ARABIC-INDIC DIGIT ZERO
    return String.fromCharCodes(
      n.toString().codeUnits.map((c) => zero + (c - 0x30)),
    );
  }
}
