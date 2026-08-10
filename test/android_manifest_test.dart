import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

/// Flutter only declares INTERNET in the debug and profile manifests. Release
/// builds merge from `main` alone, so leaving it out there silently strips
/// networking from the shipped APK: Mushaf page images fall back to text and
/// streamed recitation fails, with no error anywhere.
void main() {
  test('release manifest grants the permissions the app depends on', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    const required = {
      'android.permission.INTERNET': 'Mushaf page images and recitation',
      'android.permission.POST_NOTIFICATIONS': 'adhkar reminders',
      'android.permission.ACCESS_COARSE_LOCATION': 'prayer times',
    };

    for (final entry in required.entries) {
      expect(manifest, contains(entry.key),
          reason: 'release builds need ${entry.key} for ${entry.value}');
    }
  });
}
