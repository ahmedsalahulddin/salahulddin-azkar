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

  const IslamicBook({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.hadithCount,
    this.remoteSlug,
    this.downloadSize,
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
    ),
    IslamicBook(
      id: 'qudsi',
      title: 'الأربعون القدسية',
      author: 'مجموعة من الأحاديث القدسية',
      description: 'ما رواه النبي ﷺ عن ربه عزّ وجل',
      hadithCount: 40,
    ),
    IslamicBook(
      id: 'dehlawi',
      title: 'أربعون الدهلوي',
      author: 'شاه ولي الله الدهلوي',
      description: 'أربعون حديثاً في الرقائق والآداب',
      hadithCount: 40,
    ),
    IslamicBook(
      id: 'bukhari',
      title: 'صحيح البخاري',
      author: 'الإمام محمد بن إسماعيل البخاري',
      description: 'أصح كتاب بعد كتاب الله',
      hadithCount: 7589,
      remoteSlug: 'ara-bukhari',
      downloadSize: '٩ م.ب',
    ),
    IslamicBook(
      id: 'muslim',
      title: 'صحيح مسلم',
      author: 'الإمام مسلم بن الحجاج',
      description: 'ثاني الصحيحين',
      hadithCount: 7563,
      remoteSlug: 'ara-muslim',
      downloadSize: '٨ م.ب',
    ),
    IslamicBook(
      id: 'abudawud',
      title: 'سنن أبي داود',
      author: 'الإمام أبو داود السجستاني',
      description: 'من الكتب الستة — أحاديث الأحكام',
      hadithCount: 5274,
      remoteSlug: 'ara-abudawud',
      downloadSize: '٦ م.ب',
    ),
    IslamicBook(
      id: 'tirmidhi',
      title: 'جامع الترمذي',
      author: 'الإمام محمد بن عيسى الترمذي',
      description: 'من الكتب الستة — مع بيان درجات الأحاديث',
      hadithCount: 3956,
      remoteSlug: 'ara-tirmidhi',
      downloadSize: '٦ م.ب',
    ),
    IslamicBook(
      id: 'nasai',
      title: 'سنن النسائي',
      author: 'الإمام أحمد بن شعيب النسائي',
      description: 'من الكتب الستة',
      hadithCount: 5758,
      remoteSlug: 'ara-nasai',
      downloadSize: '٦ م.ب',
    ),
    IslamicBook(
      id: 'ibnmajah',
      title: 'سنن ابن ماجه',
      author: 'الإمام محمد بن يزيد بن ماجه',
      description: 'من الكتب الستة',
      hadithCount: 4341,
      remoteSlug: 'ara-ibnmajah',
      downloadSize: '٥ م.ب',
    ),
    IslamicBook(
      id: 'malik',
      title: 'موطأ مالك',
      author: 'الإمام مالك بن أنس',
      description: 'أقدم كتب الحديث المصنّفة',
      hadithCount: 1858,
      remoteSlug: 'ara-malik',
      downloadSize: '٢ م.ب',
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
      final request = http.Request('GET', Uri.parse('$_host/${book.remoteSlug}.json'));
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
}
