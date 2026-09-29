import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

/// A quick, dependency-free way to tell "this device has no route to the
/// internet" apart from "that one request just failed" — used to choose the
/// right message after a network-only recitation load fails, rather than
/// blaming the connection for what might be a bad URL or a server hiccup.
class ConnectivityCheck {
  static Future<bool> get online async {
    // The browser has no raw DNS lookup; the lookup below always threw
    // there, which read as "offline" and sent recovery into waiting for a
    // connection that was never missing.
    if (kIsWeb) return true;
    try {
      final result = await InternetAddress.lookup(
        'one.one.one.one',
      ).timeout(const Duration(seconds: 4));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
