import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A rendering of the meanings in another language.
///
/// None ship with the app: six translations would add roughly 10 MB for
/// something most readers never open, so each is fetched only if asked for.
class Translation {
  final String id;
  final String language;
  final String translator;

  /// Slug on the remote source.
  final String slug;

  /// Written right-to-left, like Urdu.
  final bool isRtl;

  const Translation({
    required this.id,
    required this.language,
    required this.translator,
    required this.slug,
    this.isRtl = false,
  });
}

class TranslationService {
  /// Chosen for the languages most spoken in the Kingdom, favouring works
  /// distributed freely for da'wah or long out of copyright.
  static const available = <Translation>[
    Translation(
      id: 'en',
      language: 'English',
      translator: 'Abdullah Yusuf Ali',
      slug: 'eng-abdullahyusufal',
    ),
    Translation(
      id: 'ur',
      language: 'اردو',
      translator: 'فتح محمد جالندهري',
      slug: 'urd-fatehmuhammadja',
      isRtl: true,
    ),
    Translation(
      id: 'id',
      language: 'Bahasa Indonesia',
      translator: 'مجمع الملك فهد',
      slug: 'ind-kingfahdcomplex',
    ),
    Translation(
      id: 'ms',
      language: 'Bahasa Melayu',
      translator: 'Abdullah Muhammad Basmeih',
      slug: 'msa-abdullahmuhamma',
    ),
    Translation(
      id: 'bn',
      language: 'বাংলা',
      translator: 'Abu Bakr Zakaria',
      slug: 'ben-abubakrzakaria',
    ),
    Translation(
      id: 'hi',
      language: 'हिन्दी',
      translator: 'Maulana Azizul Haque Al-Umari',
      slug: 'hin-maulanaazizulha',
    ),
    Translation(
      id: 'tr',
      language: 'Türkçe',
      translator: 'Diyanet İşleri',
      slug: 'tur-diyanetisleri',
    ),
    Translation(
      id: 'ha',
      language: 'Hausa',
      translator: 'Abubakar Mahmoud Gumi',
      slug: 'hau-abubakarmahmoud',
    ),
    Translation(
      id: 'fr',
      language: 'Français',
      translator: 'Islamic Foundation',
      slug: 'fra-islamicfoundati',
    ),
    Translation(
      id: 'fil',
      language: 'Filipino',
      translator: 'IslamHouse',
      slug: 'fil-wwwislamhouseco',
    ),
  ];

  static const _preferenceKey = '@noor_translation';
  static const _host = 'https://cdn.jsdelivr.net/gh/fawazahmed0/quran-api@1/editions';

  static Translation byId(String id) =>
      available.firstWhere((t) => t.id == id, orElse: () => available.first);

  static final Map<String, Map<int, String>> _cache = {};
  static Directory? _dir;

  static Future<Directory> _baseDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/translations');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  // ---- reader preference ----------------------------------------------

  /// The translation the reader last opened, or null if they have not picked
  /// one — the section is optional, so there is no default.
  static Future<Translation?> selected() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_preferenceKey);
    if (id == null) return null;
    return available.where((t) => t.id == id).firstOrNull;
  }

  static Future<void> select(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preferenceKey, id);
  }

  // ---- reading ---------------------------------------------------------

  /// Ayah number -> translated text for [surah].
  ///
  /// Throws if the translation has not been downloaded, so the caller can offer
  /// the download instead of showing an empty panel.
  static Future<Map<int, String>> forSurah(
    Translation translation,
    int surah,
  ) async {
    final key = '${translation.id}/$surah';
    final cached = _cache[key];
    if (cached != null) return cached;

    final file = await _fileFor(translation, surah);
    if (file == null || !await file.exists()) {
      throw StateError('${translation.language} is not downloaded');
    }

    final decoded = (jsonDecode(await file.readAsString()) as Map<String, dynamic>)
        .map((ayah, text) => MapEntry(int.parse(ayah), text as String));
    return _cache[key] = decoded;
  }

  static Future<File?> _fileFor(Translation t, int surah) async {
    if (kIsWeb) return null;
    return File('${(await _baseDir()).path}/${t.id}/$surah.json');
  }

  static Future<bool> isDownloaded(Translation t) async {
    if (kIsWeb) return false;
    final dir = Directory('${(await _baseDir()).path}/${t.id}');
    if (!await dir.exists()) return false;
    final files = await dir.list().toList();
    return files.whereType<File>().length >= 114;
  }

  // ---- downloading -----------------------------------------------------

  static bool _cancel = false;
  static void cancelDownload() => _cancel = true;

  /// Fetches all 114 surahs of [translation], reporting (done, total).
  /// Returns how many surahs failed, so a dropped connection can be resumed by
  /// running it again.
  static Future<int> download(
    Translation translation, {
    required void Function(int done, int total) onProgress,
  }) async {
    if (kIsWeb) return 0;

    _cancel = false;
    final dir = Directory('${(await _baseDir()).path}/${translation.id}');
    if (!await dir.exists()) await dir.create(recursive: true);

    final queue = [for (var s = 1; s <= 114; s++) s];
    var done = 0;
    var failed = 0;

    Future<void> worker() async {
      while (queue.isNotEmpty && !_cancel) {
        final surah = queue.removeAt(0);
        final file = File('${dir.path}/$surah.json');
        if (!await file.exists() &&
            !await _fetchSurah(translation, surah, file)) {
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
    Translation translation,
    int surah,
    File target,
  ) async {
    try {
      final res = await http
          .get(Uri.parse('$_host/${translation.slug}/$surah.json'))
          .timeout(const Duration(seconds: 30));
      if (res.statusCode != 200) return false;

      final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final verses = body['chapter'] as List?;
      if (verses == null || verses.isEmpty) return false;

      final byAyah = <String, String>{};
      for (final v in verses) {
        final m = v as Map<String, dynamic>;
        final ayah = m['verse'];
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

  static Future<void> deleteDownload(Translation t) async {
    if (kIsWeb) return;
    final dir = Directory('${(await _baseDir()).path}/${t.id}');
    if (await dir.exists()) await dir.delete(recursive: true);
    _cache.removeWhere((key, _) => key.startsWith('${t.id}/'));
  }
}
