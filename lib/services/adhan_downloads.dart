import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/adhans.dart';

/// Fetches the adhans that do not ship with the app.
///
/// A downloaded adhan can be played by the app itself — the preview button —
/// but not handed to Android as a notification sound: the system reads that
/// from a bundled resource and has no way to reach a file the app wrote. So a
/// downloaded adhan is offered for listening, and the alert keeps the bundled
/// one until the reader picks a bundled voice.
class AdhanDownloads {
  /// Which ids are on the device, so the picker can say so without hitting the
  /// filesystem on every rebuild.
  static final ready = ValueNotifier<Set<String>>({});

  /// The id currently downloading, or null.
  static final downloading = ValueNotifier<String?>(null);

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/adhans');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> fileFor(Adhan adhan) async =>
      File('${(await _dir()).path}/${adhan.id}.mp3');

  /// Reads what is already on disk. Called once at startup.
  static Future<void> refresh() async {
    if (kIsWeb) return;
    try {
      final found = <String>{};
      for (final adhan in Adhans.all) {
        if (adhan.isBundled) continue;
        if (await (await fileFor(adhan)).exists()) found.add(adhan.id);
      }
      ready.value = found;
    } catch (_) {
      // An unreadable directory just means nothing is downloaded yet.
    }
  }

  /// Returns true when the file is on the device afterwards.
  static Future<bool> fetch(Adhan adhan) async {
    final url = adhan.url;
    if (url == null || downloading.value != null) return adhan.isBundled;

    downloading.value = adhan.id;
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 60));
      // A short body is an error page, not an adhan; writing it would leave a
      // file that exists and plays nothing.
      if (response.statusCode != 200 || response.bodyBytes.length < 50000) {
        return false;
      }
      await (await fileFor(adhan)).writeAsBytes(response.bodyBytes);
      ready.value = {...ready.value, adhan.id};
      return true;
    } catch (_) {
      return false;
    } finally {
      downloading.value = null;
    }
  }

  static Future<void> remove(Adhan adhan) async {
    try {
      final file = await fileFor(adhan);
      if (await file.exists()) await file.delete();
      ready.value = {...ready.value}..remove(adhan.id);
    } catch (_) {
      // Nothing to do; the file stays and the flag with it.
    }
  }
}
