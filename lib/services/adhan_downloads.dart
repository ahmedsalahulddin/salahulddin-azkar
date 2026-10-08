import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:path_provider/path_provider.dart';

import '../data/adhans.dart';
import 'app_audio.dart';
import 'prayer_alerts.dart';

/// Fetches the adhans that do not ship with the app, and makes each one a
/// sound the system can play with a prayer alert.
///
/// Android: the system plays a channel's sound itself, so it is handed a
/// content:// link it can read (see MainActivity) to the whole adhan. iOS: only files in Library/Sounds, and only their first
/// 30 seconds, so the 29-second clip is fetched alongside and put there.
class AdhanDownloads {
  /// Which ids are on the device, so the picker can say so without hitting the
  /// filesystem on every rebuild.
  static final ready = ValueNotifier<Set<String>>({});

  /// The id currently downloading, or null.
  static final downloading = ValueNotifier<String?>(null);

  static const _native = MethodChannel('salahulddin/adhan_sound');

  static Future<Directory> _dir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory('${base.path}/adhans');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<File> fileFor(Adhan adhan) async =>
      File('${(await _dir()).path}/${adhan.resource}.m4a');

  /// Where iOS looks for a notification sound.
  static Future<File> _iosClipFor(Adhan adhan) async {
    final lib = await getLibraryDirectory();
    return File('${lib.path}/Sounds/${adhan.resource}.caf');
  }

  static bool get _ios => defaultTargetPlatform == TargetPlatform.iOS;

  static Future<bool> _complete(Adhan adhan) async {
    if (!await (await fileFor(adhan)).exists()) return false;
    return !_ios || await (await _iosClipFor(adhan)).exists();
  }

  /// Reads what is already on disk. Called once at startup.
  static Future<void> refresh() async {
    if (kIsWeb) return;
    try {
      final dir = await _dir();
      // The withdrawn voices were saved as {id}.mp3; nothing plays them now.
      await for (final f in dir.list()) {
        if (f is File && f.path.endsWith('.mp3')) {
          try {
            await f.delete();
          } catch (_) {}
        }
      }
      final found = <String>{};
      for (final adhan in Adhans.all) {
        if (adhan.isBundled) continue;
        if (await _complete(adhan)) found.add(adhan.id);
      }
      ready.value = found;
    } catch (_) {
      // An unreadable directory just means nothing is downloaded yet.
    }
  }

  static Future<List<int>?> _get(String url, int atLeast) async {
    final response = await http
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 90));
    // A short body is an error page, not an adhan; writing it would leave a
    // file that exists and plays nothing.
    if (response.statusCode != 200 || response.bodyBytes.length < atLeast) {
      return null;
    }
    return response.bodyBytes;
  }

  static Future<void> _write(File file, List<int> bytes) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.part');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  /// Returns true when the file is on the device afterwards.
  static Future<bool> fetch(Adhan adhan) async {
    final url = adhan.url;
    final clipUrl = adhan.clipUrl;
    if (url == null || clipUrl == null || downloading.value != null) {
      return adhan.isBundled;
    }

    downloading.value = adhan.id;
    try {
      final whole = await _get(url, 200000);
      if (whole == null) return false;
      if (_ios) {
        final clip = await _get(clipUrl, 50000);
        if (clip == null) return false;
        await _write(await _iosClipFor(adhan), clip);
      }
      await _write(await fileFor(adhan), whole);
      ready.value = {...ready.value, adhan.id};
      // Chosen before it arrived: the alerts were laid with the system tone.
      if (PrayerAlerts.adhan.value == adhan.id) {
        unawaited(PrayerAlerts.setAdhan(adhan.id));
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      downloading.value = null;
    }
  }

  static Future<void> remove(Adhan adhan) async {
    try {
      for (final file in [
        await fileFor(adhan),
        if (_ios) await _iosClipFor(adhan),
      ]) {
        if (await file.exists()) await file.delete();
      }
      _uris.remove(adhan.id);
      if (defaultTargetPlatform == TargetPlatform.android) {
        try {
          await _native.invokeMethod('forget', '${adhan.resource}.m4a');
        } catch (_) {}
      }
      ready.value = {...ready.value}..remove(adhan.id);
      // The alert must not point at a file that is gone.
      if (PrayerAlerts.adhan.value == adhan.id) {
        await PrayerAlerts.setAdhan(Adhans.defaultId);
      }
    } catch (_) {
      // Nothing to do; the file stays and the flag with it.
    }
  }

  static final _uris = <String, String>{};

  /// The content:// link Android's notification system can read the
  /// downloaded adhan through, or null when it is not on the device.
  static Future<String?> androidUri(Adhan adhan) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    if (!ready.value.contains(adhan.id)) return null;
    final cached = _uris[adhan.id];
    if (cached != null) return cached;
    try {
      final file = await fileFor(adhan);
      if (!await file.exists()) return null;
      final uri = await _native.invokeMethod<String>('uriFor', file.path);
      if (uri != null) _uris[adhan.id] = uri;
      return uri;
    } catch (_) {
      return null;
    }
  }

  /// Where the whole of [adhan] can be played from: the device when it is
  /// there (downloaded, cached, or Android's bundled copy). A bundled one an
  /// iPhone has not cached yet is fetched first — the data server sends whole
  /// files, not the byte ranges iOS streaming asks for.
  static Future<Uri?> sourceFor(Adhan adhan) async {
    if (kIsWeb) return null;
    final file = await fileFor(adhan);
    if (await file.exists()) return file.uri;
    if (!adhan.isBundled) return null;
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Uri.parse(
        'android.resource://com.salahulddin.azkar/raw/${adhan.resource}',
      );
    }
    final bytes = await _get('${Adhan.host}/${adhan.resource}.m4a', 200000);
    if (bytes == null) return null;
    await _write(file, bytes);
    return file.uri;
  }

  /// Plays the chosen adhan from start to end on the app's player.
  static Future<void> playFull([Adhan? which]) async {
    final adhan = which ?? Adhans.byId(PrayerAlerts.adhan.value);
    try {
      final source = await sourceFor(adhan);
      if (source == null) return;
      final player = AppAudio.player;
      await player.stop();
      await player.setAudioSource(
        AudioSource.uri(
          source,
          tag: MediaItem(
            id: 'adhan:${adhan.id}',
            title: adhan.name,
            album: adhan.place,
          ),
        ),
      );
      await player.play();
    } catch (_) {
      // No network for a bundled one on iPhone: the alert's clip was heard.
    }
  }

  /// Keeps the whole bundled adhan on an iPhone, so tapping the alert plays
  /// it offline too (the app bundle holds only the 29-second clip).
  static Future<void> cacheBundled() async {
    if (kIsWeb || !_ios) return;
    for (final adhan in Adhans.all.where((a) => a.isBundled)) {
      try {
        final file = await fileFor(adhan);
        if (await file.exists()) continue;
        final bytes = await _get('${Adhan.host}/${adhan.resource}.m4a', 200000);
        if (bytes != null) await _write(file, bytes);
      } catch (_) {
        // Fetched the first time it is played instead.
      }
    }
  }
}
