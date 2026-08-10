import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One tafsir the reader can choose between.
///
/// The two short works ship inside the app; the long ones are fetched on
/// demand, because bundling them would roughly triple the download for
/// something not every reader wants.
class TafsirEdition {
  final String id;
  final String name;
  final String author;

  /// Slug on the remote source. Null for editions bundled with the app.
  final String? remoteSlug;

  /// Rough download size, shown before the reader commits to it.
  final String? downloadSize;

  const TafsirEdition({
    required this.id,
    required this.name,
    required this.author,
    this.remoteSlug,
    this.downloadSize,
  });

  bool get isBundled => remoteSlug == null;
}

class TafsirService {
  static const editions = <TafsirEdition>[
    TafsirEdition(
      id: 'muyassar',
      name: 'التفسير الميسّر',
      author: 'مجمع الملك فهد لطباعة المصحف الشريف',
    ),
    TafsirEdition(
      id: 'mukhtasar',
      name: 'المختصر في التفسير',
      author: 'مركز تفسير للدراسات القرآنية',
    ),
    TafsirEdition(
      id: 'saadi',
      name: 'تفسير السعدي',
      author: 'عبد الرحمن بن ناصر السعدي',
      remoteSlug: 'ar-tafsir-as-saadi',
      downloadSize: '١٢ م.ب',
    ),
    TafsirEdition(
      id: 'ibn-kathir',
      name: 'تفسير ابن كثير',
      author: 'الحافظ ابن كثير',
      remoteSlug: 'ar-tafsir-ibn-kathir',
      downloadSize: '٧٠ م.ب',
    ),
  ];

  static const _preferenceKey = '@noor_tafsir_edition';
  static const _host = 'https://cdn.jsdelivr.net/gh/spa5k/tafsir_api@main/tafsir';

  static TafsirEdition get defaultEdition => editions.first;

  static TafsirEdition byId(String id) => editions.firstWhere(
        (e) => e.id == id,
        orElse: () => defaultEdition,
      );

  // Kept for the older reader screens that show a single tafsir.
  static String get name => defaultEdition.name;
  static String get publisher => defaultEdition.author;

  static final Map<String, Map<int, String>> _cache = {};
  static Directory? _dir;

  static Future<Directory> _downloadDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/tafsir');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  // ---- reader preference ----------------------------------------------

  static Future<TafsirEdition> selected() async {
    final prefs = await SharedPreferences.getInstance();
    return byId(prefs.getString(_preferenceKey) ?? defaultEdition.id);
  }

  static Future<void> select(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, id);
  }

  // ---- reading ---------------------------------------------------------

  /// Ayah number -> tafsir text for [surah] in [edition].
  ///
  /// Throws if a downloadable edition has not been fetched yet, so the caller
  /// can offer the download rather than showing an empty sheet.
  static Future<Map<int, String>> forSurahIn(
    TafsirEdition edition,
    int surah,
  ) async {
    final key = '${edition.id}/$surah';
    final cached = _cache[key];
    if (cached != null) return cached;

    final String raw;
    if (edition.isBundled) {
      raw = await rootBundle.loadString('assets/tafsir/${edition.id}/$surah.json');
    } else {
      final file = await _fileFor(edition, surah);
      if (file == null || !await file.exists()) {
        throw StateError('${edition.name} is not downloaded');
      }
      raw = await file.readAsString();
    }

    final decoded = (jsonDecode(raw) as Map<String, dynamic>).map(
      (ayah, text) => MapEntry(int.parse(ayah), text as String),
    );
    return _cache[key] = decoded;
  }

  /// Convenience for screens that only ever show the default tafsir.
  static Future<Map<int, String>> forSurah(int surah) =>
      forSurahIn(defaultEdition, surah);

  static Future<File?> _fileFor(TafsirEdition edition, int surah) async {
    if (kIsWeb) return null;
    return File('${(await _downloadDir()).path}/${edition.id}/$surah.json');
  }

  // ---- downloading -----------------------------------------------------

  static Future<bool> isDownloaded(TafsirEdition edition) async {
    if (edition.isBundled) return true;
    if (kIsWeb) return false;
    final dir = Directory('${(await _downloadDir()).path}/${edition.id}');
    if (!await dir.exists()) return false;
    final files = await dir.list().toList();
    return files.whereType<File>().length >= 114;
  }

  static bool _cancel = false;
  static void cancelDownload() => _cancel = true;

  /// Fetches all 114 surahs of [edition]. Reports (done, total) as it goes and
  /// returns the number of surahs that failed, so a flaky connection can be
  /// resumed by simply running it again.
  static Future<int> download(
    TafsirEdition edition, {
    required void Function(int done, int total) onProgress,
  }) async {
    if (edition.isBundled || kIsWeb) return 0;

    _cancel = false;
    final dir = Directory('${(await _downloadDir()).path}/${edition.id}');
    if (!await dir.exists()) await dir.create(recursive: true);

    final queue = [for (var s = 1; s <= 114; s++) s];
    var done = 0;
    var failed = 0;

    Future<void> worker() async {
      while (queue.isNotEmpty && !_cancel) {
        final surah = queue.removeAt(0);
        final file = File('${dir.path}/$surah.json');
        if (!await file.exists() && !await _fetchSurah(edition, surah, file)) {
          failed++;
        }
        done++;
        onProgress(done, 114);
      }
    }

    await Future.wait(List.generate(4, (_) => worker()));
    return failed;
  }

  static Future<bool> _fetchSurah(
    TafsirEdition edition,
    int surah,
    File target,
  ) async {
    try {
      final res = await http
          .get(Uri.parse('$_host/${edition.remoteSlug}/$surah.json'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return false;

      // Normalise to the same {ayah: text} shape the bundled editions use.
      final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
      final byAyah = <String, String>{};
      for (final item in list) {
        final m = item as Map<String, dynamic>;
        final ayah = m['ayah'] ?? m['verse'];
        final text = (m['text'] as String?)?.trim();
        if (ayah == null || text == null || text.isEmpty) continue;
        byAyah['$ayah'] = text;
      }
      if (byAyah.isEmpty) return false;

      // Write then rename, so an interrupted download never leaves a partial
      // surah that would later read as complete.
      final tmp = File('${target.path}.part');
      await tmp.writeAsString(jsonEncode(byAyah), flush: true);
      await tmp.rename(target.path);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> deleteDownload(TafsirEdition edition) async {
    if (edition.isBundled || kIsWeb) return;
    final dir = Directory('${(await _downloadDir()).path}/${edition.id}');
    if (await dir.exists()) await dir.delete(recursive: true);
    _cache.removeWhere((key, _) => key.startsWith('${edition.id}/'));
  }
}
