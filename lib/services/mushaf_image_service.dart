import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Fetches the printed Madinah Mushaf page images and keeps them on disk, so a
/// page is downloaded once and then opens instantly and offline.
///
/// Pages are not bundled with the app: 604 of them come to roughly 59 MB, which
/// would more than double the download for something most users only ever read
/// part of.
class MushafImageService {
  /// Black text on a transparent background, 1024 x 1656.
  static const imageWidth = 1024;
  static const imageAspect = 1656 / 1024;

  static const _host = 'https://files.quran.app/hafs/madani/width_1024';

  static Directory? _dir;
  static final _inFlight = <int, Future<File?>>{};

  static String urlFor(int page) =>
      '$_host/page${page.toString().padLeft(3, '0')}.png';

  static Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/mushaf');
    if (!await dir.exists()) await dir.create(recursive: true);
    return _dir = dir;
  }

  /// The cached file for [page], or null if it has not been downloaded.
  static Future<File?> cached(int page) async {
    if (kIsWeb) return null;
    final file = File('${(await _cacheDir()).path}/page$page.png');
    return await file.exists() ? file : null;
  }

  /// Downloads [page] if needed and returns the local file.
  ///
  /// Returns null on web (no filesystem) or when the download fails, so the
  /// caller can fall back to rendering the page as text.
  static Future<File?> fetch(int page) async {
    if (kIsWeb) return null;

    final existing = await cached(page);
    if (existing != null) return existing;

    // Collapse concurrent requests for the same page into one download.
    return _inFlight[page] ??= _download(page).whenComplete(() {
      _inFlight.remove(page);
    });
  }

  static Future<File?> _download(int page) async {
    try {
      final res = await http
          .get(Uri.parse(urlFor(page)))
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200 || res.bodyBytes.isEmpty) return null;

      final file = File('${(await _cacheDir()).path}/page$page.png');
      // Write beside the target then rename, so an interrupted download can
      // never leave a half-written page in the cache.
      final tmp = File('${file.path}.part');
      await tmp.writeAsBytes(res.bodyBytes, flush: true);
      await tmp.rename(file.path);
      return file;
    } catch (_) {
      return null;
    }
  }

  /// How many of the 604 pages are already on disk.
  static Future<int> cachedCount() async {
    if (kIsWeb) return 0;
    final dir = await _cacheDir();
    final files = await dir.list().toList();
    return files.whereType<File>().where((f) => f.path.endsWith('.png')).length;
  }

  static bool _cancelBulk = false;

  /// Stops an in-progress [downloadAll].
  static void cancelDownloadAll() => _cancelBulk = true;

  /// Fetches every page that is not already cached, so the Mushaf works with
  /// no connection at all. Reports (done, total) as it goes.
  ///
  /// Pages are pulled a few at a time: enough to keep the link busy without
  /// hammering the host, and each failure is counted rather than aborting the
  /// run, so a flaky connection still makes progress.
  static Future<int> downloadAll({
    required void Function(int done, int total) onProgress,
    int total = 604,
    int concurrency = 4,
  }) async {
    if (kIsWeb) return 0;

    _cancelBulk = false;
    final queue = [for (var p = 1; p <= total; p++) p];
    var done = 0;
    var failed = 0;

    Future<void> worker() async {
      while (queue.isNotEmpty && !_cancelBulk) {
        final page = queue.removeAt(0);
        if (await cached(page) == null && await fetch(page) == null) failed++;
        done++;
        onProgress(done, total);
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
    return failed;
  }

  static Future<void> clearCache() async {
    if (kIsWeb) return;
    final dir = await _cacheDir();
    if (await dir.exists()) await dir.delete(recursive: true);
    _dir = null;
  }
}
