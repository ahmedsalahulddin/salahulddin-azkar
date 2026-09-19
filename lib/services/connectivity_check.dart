import 'dart:io';

/// A quick, dependency-free way to tell "this device has no route to the
/// internet" apart from "that one request just failed" — used to choose the
/// right message after a network-only recitation load fails, rather than
/// blaming the connection for what might be a bad URL or a server hiccup.
class ConnectivityCheck {
  static Future<bool> get online async {
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
