import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// One hadith as it appears in its collection.
class Hadith {
  final int number;
  final String text;

  /// Grading, where the collection records one.
  final String? grade;

  const Hadith({required this.number, required this.text, this.grade});

  factory Hadith.fromJson(Map<String, dynamic> j) =>
      Hadith(number: j['n'], text: j['t'], grade: j['g']);
}

/// A book in the library.
class IslamicBook {
  final String id;
  final String title;
  final String author;
  final String description;
  final int hadithCount;

  /// Remote edition slug. Null for books bundled with the app.
  final String? remoteSlug;
  final String? downloadSize;

  /// Scholarly (human) translation editions this same source publishes for
  /// this book, keyed by the app's language code. Coverage genuinely varies
  /// per book — e.g. only Nawawi has Bengali, only Bukhari and Muslim have
  /// Urdu — so this is per-book data, not a fixed language list. Empty for
  /// the two Seerah books, which this source does not carry at all.
  final Map<String, String> translations;

  const IslamicBook({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.hadithCount,
    this.remoteSlug,
    this.downloadSize,
    this.translations = const {},
  });

  bool get isBundled => remoteSlug == null;
}

/// The library: three short collections travel with the app, and the large
/// canonical books are fetched on request — Bukhari and Muslim alone would add
/// 18 MB to a download most readers would never open in full.
///
/// Every work here is classical and long out of copyright.
class LibraryService {
  static const _host =
      'https://cdn.jsdelivr.net/gh/fawazahmed0/hadith-api@1/editions';

  static const books = <IslamicBook>[
    IslamicBook(
      id: 'nawawi',
      title: 'الأربعون النووية',
      author: 'الإمام يحيى بن شرف النووي',
      description: 'اثنان وأربعون حديثاً جامعة لقواعد الدين',
      hadithCount: 42,
      translations: {
        'en': 'eng-nawawi',
        'fr': 'fra-nawawi',
        'tr': 'tur-nawawi',
        'bn': 'ben-nawawi',
      },
    ),
    IslamicBook(
      id: 'qudsi',
      title: 'الأربعون القدسية',
      author: 'مجموعة من الأحاديث القدسية',
      description: 'ما رواه النبي ﷺ عن ربه عزّ وجل',
      hadithCount: 40,
      translations: {'en': 'eng-qudsi', 'fr': 'fra-qudsi'},
    ),
    IslamicBook(
      id: 'dehlawi',
      title: 'أربعون الدهلوي',
      author: 'شاه ولي الله الدهلوي',
      description: 'أربعون حديثاً في الرقائق والآداب',
      hadithCount: 40,
      translations: {'en': 'eng-dehlawi', 'fr': 'fra-dehlawi'},
    ),
    IslamicBook(
      id: 'seerah_mukhtasar',
      title: 'مختصر سيرة الرسول صلى الله عليه وسلم',
      author: 'الشيخ محمد بن عبد الوهاب',
      description: 'السيرة النبوية موجزة — البداية والمناسب لأول قراءة',
      hadithCount: 156,
    ),
    IslamicBook(
      id: 'raheeq_makhtoom',
      title: 'الرحيق المختوم',
      author: 'الشيخ صفي الرحمن المباركفوري',
      description:
          'السيرة النبوية بالتفصيل — بحث فاز بالجائزة الأولى لمسابقة رابطة العالم الإسلامي',
      hadithCount: 330,
    ),
    IslamicBook(
      id: 'bukhari',
      title: 'صحيح البخاري',
      author: 'الإمام محمد بن إسماعيل البخاري',
      description: 'أصح كتاب بعد كتاب الله',
      hadithCount: 7589,
      remoteSlug: 'ara-bukhari',
      downloadSize: '٩ م.ب',
      translations: {
        'en': 'eng-bukhari',
        'fr': 'fra-bukhari',
        'id': 'ind-bukhari',
        'tr': 'tur-bukhari',
        'ur': 'urd-bukhari',
        'bn': 'ben-bukhari',
      },
    ),
    IslamicBook(
      id: 'muslim',
      title: 'صحيح مسلم',
      author: 'الإمام مسلم بن الحجاج',
      description: 'ثاني الصحيحين',
      hadithCount: 7563,
      remoteSlug: 'ara-muslim',
      downloadSize: '٨ م.ب',
      translations: {
        'en': 'eng-muslim',
        'fr': 'fra-muslim',
        'id': 'ind-muslim',
        'tr': 'tur-muslim',
        'ur': 'urd-muslim',
        'bn': 'ben-muslim',
      },
    ),
    IslamicBook(
      id: 'abudawud',
      title: 'سنن أبي داود',
      author: 'الإمام أبو داود السجستاني',
      description: 'من الكتب الستة — أحاديث الأحكام',
      hadithCount: 5274,
      remoteSlug: 'ara-abudawud',
      downloadSize: '٦ م.ب',
      translations: {
        'en': 'eng-abudawud',
        'fr': 'fra-abudawud',
        'id': 'ind-abudawud',
        'tr': 'tur-abudawud',
        'ur': 'urd-abudawud',
        'bn': 'ben-abudawud',
      },
    ),
    IslamicBook(
      id: 'tirmidhi',
      title: 'جامع الترمذي',
      author: 'الإمام محمد بن عيسى الترمذي',
      description: 'من الكتب الستة — مع بيان درجات الأحاديث',
      hadithCount: 3956,
      remoteSlug: 'ara-tirmidhi',
      downloadSize: '٦ م.ب',
      translations: {
        'en': 'eng-tirmidhi',
        'id': 'ind-tirmidhi',
        'tr': 'tur-tirmidhi',
        'ur': 'urd-tirmidhi',
        'bn': 'ben-tirmidhi',
      },
    ),
    IslamicBook(
      id: 'nasai',
      title: 'سنن النسائي',
      author: 'الإمام أحمد بن شعيب النسائي',
      description: 'من الكتب الستة',
      hadithCount: 5758,
      remoteSlug: 'ara-nasai',
      downloadSize: '٦ م.ب',
      translations: {
        'en': 'eng-nasai',
        'fr': 'fra-nasai',
        'id': 'ind-nasai',
        'tr': 'tur-nasai',
        'ur': 'urd-nasai',
        'bn': 'ben-nasai',
      },
    ),
    IslamicBook(
      id: 'ibnmajah',
      title: 'سنن ابن ماجه',
      author: 'الإمام محمد بن يزيد بن ماجه',
      description: 'من الكتب الستة',
      hadithCount: 4341,
      remoteSlug: 'ara-ibnmajah',
      downloadSize: '٥ م.ب',
      translations: {
        'en': 'eng-ibnmajah',
        'fr': 'fra-ibnmajah',
        'id': 'ind-ibnmajah',
        'tr': 'tur-ibnmajah',
        'ur': 'urd-ibnmajah',
        'bn': 'ben-ibnmajah',
      },
    ),
    IslamicBook(
      id: 'malik',
      title: 'موطأ مالك',
      author: 'الإمام مالك بن أنس',
      description: 'أقدم كتب الحديث المصنّفة',
      hadithCount: 1858,
      remoteSlug: 'ara-malik',
      downloadSize: '٢ م.ب',
      translations: {
        'en': 'eng-malik',
        'fr': 'fra-malik',
        'id': 'ind-malik',
        'tr': 'tur-malik',
        'ur': 'urd-malik',
        'bn': 'ben-malik',
      },
    ),
  ];

  static IslamicBook byId(String id) =>
      books.firstWhere((b) => b.id == id, orElse: () => books.first);

  static final Map<String, List<Hadith>> _cache = {};
  static Directory? _dir;

  static Future<Directory> _baseDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/books');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  /// Throws if a downloadable book has not been fetched, so the caller can
  /// offer the download rather than showing an empty shelf.
  static Future<List<Hadith>> hadiths(IslamicBook book) async {
    final cached = _cache[book.id];
    if (cached != null) return cached;

    final String raw;
    if (book.isBundled) {
      raw = await rootBundle.loadString('assets/books/${book.id}.json');
    } else {
      final file = await _fileFor(book);
      if (file == null || !await file.exists()) {
        throw StateError('${book.title} is not downloaded');
      }
      raw = await file.readAsString();
    }

    final j = jsonDecode(raw) as Map<String, dynamic>;
    return _cache[book.id] = (j['hadiths'] as List)
        .map((e) => Hadith.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<File?> _fileFor(IslamicBook book) async {
    if (kIsWeb) return null;
    return File('${(await _baseDir()).path}/${book.id}.json');
  }

  static Future<bool> isDownloaded(IslamicBook book) async {
    if (book.isBundled) return true;
    if (kIsWeb) return false;
    final file = await _fileFor(book);
    return file != null && await file.exists();
  }

  /// Downloads [book] whole — these arrive as a single file, so progress is
  /// reported by bytes received rather than by chapter.
  static Future<bool> download(
    IslamicBook book, {
    required void Function(int received, int? total) onProgress,
  }) async {
    if (book.isBundled || kIsWeb) return true;

    try {
      final request = http.Request(
        'GET',
        Uri.parse('$_host/${book.remoteSlug}.json'),
      );
      final response = await http.Client().send(request);
      if (response.statusCode != 200) return false;

      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        onProgress(bytes.length, response.contentLength);
      }

      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final hadiths = <Map<String, dynamic>>[];
      for (final h in (decoded['hadiths'] as List? ?? [])) {
        final m = h as Map<String, dynamic>;
        final text = (m['text'] as String?)?.trim();
        if (text == null || text.isEmpty) continue;
        final entry = <String, dynamic>{'n': m['hadithnumber'], 't': text};
        final grade = (m['grades'] as List? ?? [])
            .map((g) => (g as Map)['grade'])
            .whereType<String>()
            .firstOrNull;
        if (grade != null) entry['g'] = grade;
        hadiths.add(entry);
      }
      if (hadiths.isEmpty) return false;

      // Write then rename, so an interrupted download never leaves a partial
      // book that would later read as complete.
      final target = await _fileFor(book);
      if (target == null) return false;
      final tmp = File('${target.path}.part');
      await tmp.writeAsString(
        jsonEncode({'id': book.id, 'hadiths': hadiths}),
        flush: true,
      );
      await tmp.rename(target.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteDownload(IslamicBook book) async {
    if (book.isBundled || kIsWeb) return;
    final file = await _fileFor(book);
    if (file != null && await file.exists()) await file.delete();
    _cache.remove(book.id);
  }

  // ---- translations --------------------------------------------------
  //
  // The same source that supplies each book's Arabic text also publishes
  // scholarly translation editions of most of them (never all the app's
  // languages — coverage is per book, see IslamicBook.translations). These
  // are cached exactly like the Arabic download, just keyed by book+language
  // rather than by book alone, and mapped by hadith number rather than kept
  // as a plain list, since a translation is only ever read alongside the
  // Arabic hadith it matches.

  static final Map<String, Map<int, String>> _translationCache = {};

  static Future<File?> _translationFileFor(
    IslamicBook book,
    String lang,
  ) async {
    if (kIsWeb) return null;
    return File('${(await _baseDir()).path}/${book.id}_$lang.json');
  }

  static Future<bool> isTranslationDownloaded(
    IslamicBook book,
    String lang,
  ) async {
    if (kIsWeb) return false;
    final file = await _translationFileFor(book, lang);
    return file != null && await file.exists();
  }

  /// Throws if [lang]'s edition has not been downloaded for [book], so the
  /// caller can offer the download rather than showing blank translations.
  static Future<Map<int, String>> translation(
    IslamicBook book,
    String lang,
  ) async {
    final key = '${book.id}_$lang';
    final cached = _translationCache[key];
    if (cached != null) return cached;

    final file = await _translationFileFor(book, lang);
    if (file == null || !await file.exists()) {
      throw StateError('${book.title} has no $lang translation downloaded');
    }
    final j = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final map = <int, String>{
      for (final e in (j['hadiths'] as List))
        (e as Map<String, dynamic>)['n'] as int: e['t'] as String,
    };
    return _translationCache[key] = map;
  }

  static Future<bool> downloadTranslation(
    IslamicBook book,
    String lang, {
    required void Function(int received, int? total) onProgress,
  }) async {
    final slug = book.translations[lang];
    if (slug == null || kIsWeb) return false;

    try {
      final request = http.Request('GET', Uri.parse('$_host/$slug.json'));
      final response = await http.Client().send(request);
      if (response.statusCode != 200) return false;

      final bytes = <int>[];
      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        onProgress(bytes.length, response.contentLength);
      }

      final decoded = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final hadiths = <Map<String, dynamic>>[];
      for (final h in (decoded['hadiths'] as List? ?? [])) {
        final m = h as Map<String, dynamic>;
        final text = (m['text'] as String?)?.trim();
        final number = m['hadithnumber'];
        if (text == null || text.isEmpty || number == null) continue;
        hadiths.add({'n': number, 't': text});
      }
      if (hadiths.isEmpty) return false;

      final target = await _translationFileFor(book, lang);
      if (target == null) return false;
      final tmp = File('${target.path}.part');
      await tmp.writeAsString(
        jsonEncode({'id': book.id, 'lang': lang, 'hadiths': hadiths}),
        flush: true,
      );
      await tmp.rename(target.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteTranslation(IslamicBook book, String lang) async {
    if (kIsWeb) return;
    final file = await _translationFileFor(book, lang);
    if (file != null && await file.exists()) await file.delete();
    _translationCache.remove('${book.id}_$lang');
  }
}
