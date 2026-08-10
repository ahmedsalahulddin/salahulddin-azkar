import 'dart:async';
import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// The Supabase project's public credentials.
///
/// The anon key is meant to be shipped inside clients — it carries no
/// privileges of its own and every table is guarded by row-level security — so
/// it lives here rather than in a build flag that is easy to forget. A build
/// flag still overrides it, which is what a second environment would use.
///
/// The service_role key must never appear in this app.
class AuthConfig {
  static const _defaultUrl = 'https://inxmkqszfbzixpexgolw.supabase.co';
  static const _defaultAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlueG1rcXN6ZmJ6aXhwZXhnb2x3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYxODk3MjIsImV4cCI6MjEwMTc2NTcyMn0.E8bHRxdQmvVjLhB3a3WK53XXrr2kAwKpcrZuA1xSIpU';

  static const url =
      String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultUrl);
  static const anonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: _defaultAnonKey);

  /// Where the provider returns to after sign-in.
  ///
  /// On a device this is the app's own deep link, registered in
  /// AndroidManifest. On the web there is no deep link to return to, so the
  /// project's Site URL is used instead — passing the app scheme there would
  /// strand the browser on a URL it cannot open.
  static String? get redirect =>
      kIsWeb ? null : 'com.salahulddin.azkar://login-callback';

  static bool get isSet => url.isNotEmpty && anonKey.isNotEmpty;
}

/// The sign-in methods the app knows how to present.
///
/// Each carries the brand's own wording, because every one of these companies
/// requires its button to say and look like their own — a generic "sign in"
/// button is a policy violation, not just a style choice.
enum SignInProvider {
  google('google', 'Google', 'المتابعة باستخدام Google'),
  facebook('facebook', 'Facebook', 'المتابعة باستخدام Facebook'),
  apple('apple', 'Apple', 'المتابعة باستخدام Apple');

  /// Name Supabase reports this provider under.
  final String key;
  final String brand;
  final String label;

  const SignInProvider(this.key, this.brand, this.label);

  OAuthProvider get oauth => switch (this) {
        SignInProvider.google => OAuthProvider.google,
        SignInProvider.facebook => OAuthProvider.facebook,
        SignInProvider.apple => OAuthProvider.apple,
      };
}

/// A signed-in person, or null when reading as a guest.
class AppUser {
  final String id;
  final String? name;
  final String? email;
  final String? photoUrl;

  const AppUser({
    required this.id,
    this.name,
    this.email,
    this.photoUrl,
  });

  String get displayName => name?.trim().isNotEmpty == true
      ? name!
      : email?.split('@').first ?? 'مستخدم';

  /// First letters of the name, for the avatar when there is no photo.
  String get initials {
    final source = displayName.trim();
    if (source.isEmpty) return '؟';
    final parts = source.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.characters.first;
    return '${parts.first.characters.first}${parts[1].characters.first}';
  }
}

/// Signing in is optional throughout: it exists to carry favourites,
/// bookmarks and reading position between devices, not to gate the app.
class AuthService {
  static bool _initialised = false;

  /// Rebuilt-on-change handle for the current user, so any screen can react to
  /// signing in or out without polling.
  static final user = ValueNotifier<AppUser?>(null);

  /// False until the project credentials are supplied.
  static bool get isConfigured => AuthConfig.isSet;

  /// Which sign-in methods the Supabase project actually offers.
  ///
  /// Asked of the project rather than assumed, so a button appears the moment
  /// its provider is switched on in the dashboard — no new build — and is never
  /// offered while it could only fail.
  static final availableProviders = ValueNotifier<Set<SignInProvider>>({});

  /// Kept for callers that only care about Google.
  static bool get googleAvailable =>
      availableProviders.value.contains(SignInProvider.google);

  static Future<void> init() async {
    if (_initialised || !isConfigured) return;

    await Supabase.initialize(
      url: AuthConfig.url,
      // The dashboard now calls this the publishable key; the build flag keeps
      // the older name readers will recognise.
      publishableKey: AuthConfig.anonKey,
    );
    _initialised = true;

    _adopt(Supabase.instance.client.auth.currentSession?.user);
    Supabase.instance.client.auth.onAuthStateChange.listen((state) {
      _adopt(state.session?.user);
    });

    unawaited(refreshProviders());
  }

  /// Reads which sign-in methods the project actually offers.
  static Future<void> refreshProviders() async {
    if (!isConfigured) return;
    try {
      final res = await http.get(
        Uri.parse('${AuthConfig.url}/auth/v1/settings'),
        headers: {'apikey': AuthConfig.anonKey},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final external =
          (jsonDecode(res.body) as Map<String, dynamic>)['external'];
      if (external is! Map) return;

      availableProviders.value = {
        for (final provider in SignInProvider.values)
          if (external[provider.key] == true) provider,
      };
    } catch (_) {
      // Leave them off: offering a button that cannot work is worse than
      // hiding it.
    }
  }

  static void _adopt(User? account) {
    if (account == null) {
      user.value = null;
      return;
    }
    final meta = account.userMetadata ?? const {};
    user.value = AppUser(
      id: account.id,
      name: (meta['full_name'] ?? meta['name']) as String?,
      email: account.email,
      photoUrl: (meta['avatar_url'] ?? meta['picture']) as String?,
    );
  }

  /// Opens the chosen provider's sign-in. Returns false if it was cancelled or
  /// failed, so the caller can stay silent rather than claiming success.
  static Future<bool> signInWith(SignInProvider provider) async {
    if (!isConfigured) return false;
    await init();
    try {
      return await Supabase.instance.client.auth.signInWithOAuth(
        provider.oauth,
        redirectTo: AuthConfig.redirect,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> signInWithGoogle() => signInWith(SignInProvider.google);

  static Future<void> signOut() async {
    if (!_initialised) return;
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (_) {
      // Clearing the local session is what matters to the reader.
    }
    user.value = null;
  }
}
