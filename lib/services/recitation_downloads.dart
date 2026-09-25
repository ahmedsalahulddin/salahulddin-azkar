import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/quran_data.dart';
import 'recitation_service.dart';

/// Recitation audio saved for offline listening, one surah at a time.
///
/// A per-ayah reciter needs every ayah in the surah on disk before it counts
/// as downloaded; a per-surah reciter (mp3quran.net) needs just the one
/// file. Either way, files land under the reciter's own folder keyed only by
/// reciter and surah — not by which screen fetched them — so a surah
/// downloaded once from anywhere plays offline everywhere: the surah
/// screen, the Mushaf, the translation screen, and continuous listening all
/// resolve audio through [sourceFor].
class RecitationDownloads {
  RecitationDownloads._();

  static const _readyPrefsKey = '@noor_recitation_downloads';

  /// "$reciterId:$surah" keys that are fully on disk.
  static final ready = ValueNotifier<Set<String>>({});

  /// "$reciterId:$surah" currently downloading, with progress 0..1 (null
  /// progress means "started, size not known yet").
  static final active = ValueNotifier<MapEntry<String, double?>?>(null);

  static String keyOf(String reciterId, int surah) => '$reciterId:$surah';

  static bool isReady(String reciterId, int surah) =>
      ready.value.contains(keyOf(reciterId, surah));

  static Future<Directory> _dir(String reciterId) async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/recitations/$reciterId');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> fileFor({
    required String reciterId,
    required int surah,
    int? ayah,
  }) async {
    final dir = await _dir(reciterId);
    final name = ayah == null
        ? '$surah.mp3'
        : '$surah-${ayah.toString().padLeft(3, '0')}.mp3';
    return File('${dir.path}/$name');
  }

  /// The URI to play from: the local file when this surah has been
  /// downloaded for [reciter], otherwise the network URL. Every playback
  /// path in the app should build its audio source through this rather than
  /// calling [RecitationService] directly, so a download made from anywhere
  /// is honoured everywhere.
  static Future<Uri> sourceFor({
    required Reciter reciter,
    required int surah,
    int? ayah,
  }) async {
    if (isReady(reciter.id, surah)) {
      final file = await fileFor(
        reciterId: reciter.id,
        surah: surah,
        ayah: reciter.isPerAyah ? ayah : null,
      );
      if (await file.exists()) return Uri.file(file.path);
    }
    if (reciter.isPerAyah) {
      return Uri.parse(
        RecitationService.urlFor(
          reciterId: reciter.id,
          surah: surah,
          ayah: ayah!,
        ),
      );
    }
    return Uri.parse(
      RecitationService.surahUrlFor(reciter: reciter, surah: surah)!,
    );
  }

  /// Reads what is already on disk. Called once at startup.
  static Future<void> refresh() async {
    if (kIsWeb) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      ready.value = (prefs.getStringList(_readyPrefsKey) ?? const []).toSet();
    } catch (_) {
      // Nothing downloaded yet, as far as this session knows.
    }
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_readyPrefsKey, ready.value.toList());
    } catch (_) {
      // The download still holds for this session even if this fails.
    }
  }

  /// Downloads every file [info]'s surah needs for [reciter], skipping any
  /// already on disk so an interrupted download can simply be retried.
  /// Returns true only once every file made it.
  static Future<bool> download({
    required Reciter reciter,
    required SurahInfo info,
    void Function(int done, int total)? onProgress,
  }) async {
    final key = keyOf(reciter.id, info.number);
    if (ready.value.contains(key)) return true;
    if (active.value != null) return false; // one download at a time

    active.value = MapEntry(key, 0);
    try {
      if (reciter.isPerAyah) {
        for (var n = 1; n <= info.ayahCount; n++) {
          active.value = MapEntry(key, (n - 1) / info.ayahCount);
          onProgress?.call(n - 1, info.ayahCount);
          final file = await fileFor(
            reciterId: reciter.id,
            surah: info.number,
            ayah: n,
          );
          if (await file.exists()) continue;
          final ok = await _fetch(
            RecitationService.urlFor(
              reciterId: reciter.id,
              surah: info.number,
              ayah: n,
            ),
            file,
          );
          if (!ok) return false;
        }
        onProgress?.call(info.ayahCount, info.ayahCount);
      } else {
        final url = RecitationService.surahUrlFor(
          reciter: reciter,
          surah: info.number,
        );
        if (url == null) return false;
        final ok = await _fetch(
          url,
          await fileFor(reciterId: reciter.id, surah: info.number),
        );
        if (!ok) return false;
        onProgress?.call(1, 1);
      }

      ready.value = {...ready.value, key};
      await _persist();
      return true;
    } catch (_) {
      return false;
    } finally {
      active.value = null;
    }
  }

  static Future<bool> _fetch(String url, File file) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 30));
    // A short body is an error page, not audio; writing it would leave a
    // file that exists on disk but plays nothing.
    if (response.statusCode != 200 || response.bodyBytes.length < 1000) {
      return false;
    }
    await file.writeAsBytes(response.bodyBytes);
    return true;
  }

  static Future<void> remove({
    required String reciterId,
    required int surah,
  }) async {
    try {
      final dir = await _dir(reciterId);
      if (await dir.exists()) {
        await for (final entry in dir.list()) {
          if (entry is! File) continue;
          final name = entry.uri.pathSegments.last;
          if (name == '$surah.mp3' || name.startsWith('$surah-')) {
            await entry.delete();
          }
        }
      }
    } catch (_) {
      // Nothing to do on disk; the flag still clears below.
    }
    ready.value = {...ready.value}..remove(keyOf(reciterId, surah));
    await _persist();
  }

  /// How many of [reciterId]'s surahs are on the device.
  static int countFor(String reciterId) =>
      ready.value.where((k) => k.startsWith('$reciterId:')).length;

  /// Every downloaded surah of [reciterId], in one go.
  static Future<void> removeAllFor(String reciterId) async {
    final surahs = [
      for (final k in ready.value)
        if (k.startsWith('$reciterId:')) int.parse(k.split(':').last),
    ];
    for (final s in surahs) {
      await remove(reciterId: reciterId, surah: s);
    }
  }
}
