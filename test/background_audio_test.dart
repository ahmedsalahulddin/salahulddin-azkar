import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Recitation has to survive the reader leaving the app. On Android that is
/// not a Dart concern — it is a foreground media service, and it only exists
/// if the manifest declares it. This is the piece that silently regresses,
/// exactly like the INTERNET permission did.
void main() {
  late String manifest;

  setUpAll(() {
    manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
  });

  test('the media service and its permissions are declared', () {
    const required = {
      'android.permission.FOREGROUND_SERVICE': 'the service may run at all',
      'android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK':
          'Android 14 requires the playback type',
      'android.permission.WAKE_LOCK': 'playback continues with the screen off',
    };
    for (final entry in required.entries) {
      expect(manifest, contains(entry.key), reason: 'needed so ${entry.value}');
    }

    expect(manifest, contains('com.ryanheise.audioservice.AudioService'));
    expect(manifest, contains('android:foregroundServiceType="mediaPlayback"'));
    expect(manifest, contains('android.media.browse.MediaBrowserService'));
  });

  test('the notification can bring the app back', () {
    // Tapping the notification reopens the activity, which only works when it
    // is audio_service's own.
    expect(manifest, contains('com.ryanheise.audioservice.AudioServiceActivity'));
    expect(manifest, contains('com.ryanheise.audioservice.MediaButtonReceiver'));
    expect(manifest, contains('android.intent.action.MEDIA_BUTTON'));
  });

  test('every player labels its audio, or the service refuses it', () {
    // just_audio_background needs a MediaItem on each source; a source without
    // one throws at play time rather than at build time.
    for (final path in [
      'lib/screens/mushaf_screen.dart',
      'lib/screens/surah_screen.dart',
      'lib/widgets/dhikr_audio.dart',
      'lib/widgets/adhkar_card.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('MediaItem('), reason: '$path plays untagged audio');
      expect(source, isNot(contains('.setUrl(')),
          reason: '$path uses setUrl, which cannot carry a MediaItem');
    }
  });

  test('the radio and the speech engine survive a release build', () {
    // Radiojar redirects https to a plain-http media node; without the
    // security config Android refuses the stream, and without the TTS_SERVICE
    // query Android 11+ hides every speech engine. Both fail only on a real
    // phone, which is exactly why they are pinned here.
    expect(manifest, contains('android:networkSecurityConfig'));
    expect(manifest, contains('android.intent.action.TTS_SERVICE'));
    final config = File('android/app/src/main/res/xml/network_security_config.xml')
        .readAsStringSync();
    expect(config, contains('radiojar.com'));
    expect(config,
        contains('<base-config cleartextTrafficPermitted="false"/>'),
        reason: 'cleartext must stay off for everything except the radio');
  });

  test('the background service is started before any player is built', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains('JustAudioBackground.init('));
    expect(main.indexOf('JustAudioBackground.init('),
        lessThan(main.indexOf('runApp(')));
  });
}
