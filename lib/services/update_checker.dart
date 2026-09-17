import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Where an update was found, so the UI can offer the right action —
/// Play Store installs update in place; sideloaded APKs need a new download.
enum UpdateSource { playStore, github }

class UpdateCheckResult {
  final bool available;
  final String? latestVersion;
  final UpdateSource? source;

  /// True when the check itself failed (no network, GitHub unreachable) —
  /// distinct from a genuine "you're up to date" so the UI can tell them apart.
  final bool failed;

  const UpdateCheckResult({
    required this.available,
    this.latestVersion,
    this.source,
    this.failed = false,
  });
}

/// Checks for a newer release two ways: Google Play's own in-app update API
/// (works only for installs that came from the Store) and the GitHub
/// Releases API (works for the sideloaded APK from the download page,
/// which is what most readers have while the app sits in internal testing).
class UpdateChecker {
  static const _repo = 'ahmedsalahulddin/salahulddin-azkar';
  static const downloadPageUrl = 'https://azkar.salahulddin.com/download';

  static Future<UpdateCheckResult> check() async {
    if (Platform.isAndroid) {
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          return const UpdateCheckResult(
            available: true,
            source: UpdateSource.playStore,
          );
        }
        if (info.updateAvailability == UpdateAvailability.updateNotAvailable) {
          return const UpdateCheckResult(available: false);
        }
        // Unknown availability (e.g. not installed via Play) — fall through
        // to the GitHub check below rather than reporting up to date.
      } catch (_) {
        // Not distributed via Play Store (debug build, sideloaded APK).
      }
    }

    try {
      final current = (await PackageInfo.fromPlatform()).version;
      final res = await http
          .get(Uri.parse('https://api.github.com/repos/$_repo/releases/latest'))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        return const UpdateCheckResult(available: false, failed: true);
      }
      final tag = (jsonDecode(res.body) as Map)['tag_name'] as String? ?? '';
      final latest = tag.startsWith('v') ? tag.substring(1) : tag;
      if (latest.isNotEmpty && _isNewer(latest, current)) {
        return UpdateCheckResult(
          available: true,
          latestVersion: latest,
          source: UpdateSource.github,
        );
      }
      return const UpdateCheckResult(available: false);
    } catch (_) {
      return const UpdateCheckResult(available: false, failed: true);
    }
  }

  /// Immediate in-place update through Google Play — only valid to call when
  /// [check] reported [UpdateSource.playStore].
  static Future<void> startPlayStoreUpdate() async {
    try {
      await InAppUpdate.performImmediateUpdate();
    } catch (_) {
      // The user backed out, or Play could not start it — nothing to recover.
    }
  }

  /// Numeric, dot-separated comparison ("1.5.9" vs "1.5.10") — a plain string
  /// compare would wrongly rank "1.5.10" below "1.5.9".
  static bool _isNewer(String a, String b) {
    final pa = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final pb = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final length = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < length; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }
}
