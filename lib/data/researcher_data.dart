import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Which shelf of «الباحث القرآني» a book sits on.
enum ResearcherCategory { tafsir, gharib, irab, asbab }

/// One classical book of «الباحث القرآني». Only works of the salaf and the
/// people of athar are listed (see the catalogue), each as its printed
/// pages, with the modern editors' footnotes removed.
class ResearcherBook {
  final int id;
  final ResearcherCategory category;
  final String name;
  final String author;
  final String death;
  final Set<int> surahs;
  final int bytes;

  const ResearcherBook({
    required this.id,
    required this.category,
    required this.name,
    required this.author,
    required this.death,
    required this.surahs,
    required this.bytes,
  });

  factory ResearcherBook.fromJson(Map<String, dynamic> j) => ResearcherBook(
    id: j['id'] as int,
    category: ResearcherCategory.values.firstWhere(
      (c) => c.name == j['cat'],
      orElse: () => ResearcherCategory.tafsir,
    ),
    name: j['name'] as String,
    author: j['author'] as String? ?? '',
    death: '${j['death'] ?? ''}',
    surahs: {for (final s in (j['surahs'] as List? ?? const [])) s as int},
    bytes: (j['bytes'] as num?)?.toInt() ?? 0,
  );
}

/// The pages of one book that speak about one ayah.
class ResearcherPage {
  /// "part-page" of the printed edition, e.g. "1-32".
  final String id;
  final String text;

  const ResearcherPage(this.id, this.text);

  String get part => id.split('-').first;
  String get page => id.split('-').last;
}

/// A search hit.
class ResearcherHit {
  final ResearcherBook book;
  final int surah;
  final int ayah;
  final String snippet;

  const ResearcherHit(this.book, this.surah, this.ayah, this.snippet);
}

class ResearcherService {
  /// Where the converted books are served from (a Cloudflare Worker of the
  /// app's own), one file per book and surah: {p: {page: text}, a: {ayah:
  /// [page ids]}}.
  static const host = 'https://qdata.salahulddin.com/qr';

  static List<ResearcherBook>? _catalog;

  /// The book list, bundled with the app so the shelves show offline.
  static Future<List<ResearcherBook>> catalog() async {
    final cached = _catalog;
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString('assets/researcher/catalog.json');
      return _catalog = [
        for (final j in (jsonDecode(raw) as List).cast<Map<String, dynamic>>())
          ResearcherBook.fromJson(j),
      ];
    } catch (_) {
      return _catalog = const [];
    }
  }

  static Directory? _dir;
  static Future<Directory> _root() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/researcher');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  static Future<File> _file(int book, int surah) async =>
      File('${(await _root()).path}/$book/$surah.json');

  static final Map<String, Map<String, dynamic>> _memo = {};

  /// One surah of a book: read from the device if it was fetched before,
  /// otherwise fetched now and kept. Null when the book has nothing on this
  /// surah or the network is out.
  static Future<Map<String, dynamic>?> _surah(int book, int surah) async {
    final key = '$book/$surah';
    final memo = _memo[key];
    if (memo != null) return memo;
    try {
      if (!kIsWeb) {
        final file = await _file(book, surah);
        if (await file.exists()) {
          return _memo[key] =
              jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        }
      }
      final res = await http
          .get(Uri.parse('$host/$book/$surah.json'))
          .timeout(const Duration(seconds: 40));
      if (res.statusCode != 200) return null;
      final body = utf8.decode(res.bodyBytes);
      final data = jsonDecode(body) as Map<String, dynamic>;
      if (!kIsWeb) {
        final file = await _file(book, surah);
        await file.parent.create(recursive: true);
        final tmp = File('${file.path}.part');
        await tmp.writeAsString(body, flush: true);
        await tmp.rename(file.path);
      }
      return _memo[key] = data;
    } catch (_) {
      return null;
    }
  }

  /// The pages of [book] linked to [surah]:[ayah], in reading order. Null
  /// when they could not be fetched; empty when the book is silent on it.
  static Future<List<ResearcherPage>?> pagesFor(
    ResearcherBook book,
    int surah,
    int ayah,
  ) async {
    if (!book.surahs.contains(surah)) return const [];
    final data = await _surah(book.id, surah);
    if (data == null) return null;
    final pages = (data['p'] as Map).cast<String, dynamic>();
    final ids = ((data['a'] as Map)['$ayah'] as List?)?.cast<String>() ?? [];
    return [
      for (final id in ids)
        if (pages[id] != null) ResearcherPage(id, pages[id] as String),
    ];
  }

  // ---- whole-book downloads (for reading offline and for search) --------

  static Future<bool> isDownloaded(ResearcherBook book) async {
    if (kIsWeb) return false;
    for (final s in book.surahs) {
      if (!await (await _file(book.id, s)).exists()) return false;
    }
    return true;
  }

  /// Fetches every surah of [book] not yet on the device. Returns how many
  /// could not be fetched.
  static Future<int> download(
    ResearcherBook book, {
    required void Function(int done, int total) onProgress,
  }) async {
    final todo = book.surahs.toList()..sort();
    var done = 0;
    var failed = 0;
    Future<void> worker() async {
      while (todo.isNotEmpty) {
        final s = todo.removeAt(0);
        if (await _surah(book.id, s) == null) failed++;
        done++;
        onProgress(done, book.surahs.length);
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
    return failed;
  }

  static Future<void> deleteDownload(ResearcherBook book) async {
    if (kIsWeb) return;
    final dir = Directory('${(await _root()).path}/${book.id}');
    if (await dir.exists()) await dir.delete(recursive: true);
    _memo.removeWhere((key, _) => key.startsWith('${book.id}/'));
  }

  // ---- search -----------------------------------------------------------

  /// Searches the downloaded books for [query], ignoring diacritics and
  /// letter forms (أ/إ/آ/ا, ة/ه, ى/ي). At most [limit] hits.
  static Future<List<ResearcherHit>> search(
    String query, {
    int limit = 200,
  }) async {
    final q = normalize(query.trim());
    if (q.length < 2 || kIsWeb) return const [];
    final hits = <ResearcherHit>[];
    for (final book in await catalog()) {
      final dir = Directory('${(await _root()).path}/${book.id}');
      if (!await dir.exists()) continue;
      final files = await dir
          .list()
          .where((f) => f.path.endsWith('.json'))
          .cast<File>()
          .toList();
      for (final f in files) {
        final surah = int.tryParse(f.uri.pathSegments.last.split('.').first);
        if (surah == null) continue;
        final found = await compute(_searchFile, (
          await f.readAsString(),
          q,
          limit - hits.length,
        ));
        for (final (ayah, snippet) in found) {
          hits.add(ResearcherHit(book, surah, ayah, snippet));
        }
        if (hits.length >= limit) return hits;
      }
    }
    return hits;
  }

  static final _marks = RegExp('[ؐ-ًؚ-ٰٟۖ-ۭـ]');

  static String normalize(String s) => s
      .replaceAll(_marks, '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي');
}

/// Runs off the main isolate: finds [query] in one surah file and returns
/// (first ayah linked to the page, snippet) pairs.
List<(int, String)> _searchFile((String, String, int) args) {
  final (raw, query, limit) = args;
  final data = jsonDecode(raw) as Map<String, dynamic>;
  final pages = (data['p'] as Map).cast<String, dynamic>();
  final firstAyah = <String, int>{};
  for (final e in (data['a'] as Map).entries) {
    for (final id in (e.value as List).cast<String>()) {
      final a = int.parse(e.key as String);
      final old = firstAyah[id];
      if (old == null || a < old) firstAyah[id] = a;
    }
  }
  final out = <(int, String)>[];
  for (final e in pages.entries) {
    final text = e.value as String;
    final norm = ResearcherService.normalize(text);
    final i = norm.indexOf(query);
    if (i < 0) continue;
    // The normalized text is shorter than the original (marks removed), so
    // the snippet is taken from the normalized text itself.
    final start = (i - 60).clamp(0, norm.length);
    final end = (i + query.length + 60).clamp(0, norm.length);
    out.add((
      firstAyah[e.key] ?? 1,
      '${start > 0 ? '…' : ''}${norm.substring(start, end).replaceAll('\n', ' ')}${end < norm.length ? '…' : ''}',
    ));
    if (out.length >= limit) break;
  }
  return out;
}
