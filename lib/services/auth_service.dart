import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:characters/characters.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultUrl,
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: _defaultAnonKey,
  );

  /// Where the provider returns to after sign-in.
  ///
  /// On a device this is the app's own deep link, registered in
  /// AndroidManifest. On the web it is the site the reader is on — not the
  /// project's Site URL, which once pointed at a domain that no longer
  /// exists. The origin must be listed in the project's Redirect URLs.
  static String? get redirect =>
      kIsWeb ? '${Uri.base.origin}/' : 'com.salahulddin.azkar://login-callback';

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

  /// Whether [photoUrl] is one the reader chose in the app.
  final bool hasCustomPhoto;

  const AppUser({
    required this.id,
    this.name,
    this.email,
    this.photoUrl,
    this.hasCustomPhoto = false,
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

  /// What this platform may offer out of [enabled]. App Store Review
  /// Guideline 4.8: an iPhone app that offers a third-party sign-in must offer
  /// Sign in with Apple beside it, so on iOS every button stays hidden until
  /// Apple is switched on for the project — and then all of them appear at
  /// once, without an app update.
  static Set<SignInProvider> offeredOn(
    TargetPlatform platform,
    Set<SignInProvider> enabled,
  ) {
    if (kIsWeb || platform != TargetPlatform.iOS) {
      // Apple is signed into natively on iPhone only. Elsewhere it would go
      // through the web flow, which needs a Services ID and a signing key
      // this project does not have — so the button would only fail.
      return {...enabled}..remove(SignInProvider.apple);
    }
    return enabled.contains(SignInProvider.apple) ? enabled : {};
  }

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
      final res = await http
          .get(
            Uri.parse('${AuthConfig.url}/auth/v1/settings'),
            headers: {'apikey': AuthConfig.anonKey},
          )
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final external =
          (jsonDecode(res.body) as Map<String, dynamic>)['external'];
      if (external is! Map) return;

      availableProviders.value = offeredOn(defaultTargetPlatform, {
        for (final provider in SignInProvider.values)
          if (external[provider.key] == true) provider,
      });
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
      // A picture the reader chose in the app wins over the provider's, and
      // lives under its own key so signing in again doesn't overwrite it.
      photoUrl:
          (meta[_customAvatarKey] ?? meta['avatar_url'] ?? meta['picture'])
              as String?,
      hasCustomPhoto: meta[_customAvatarKey] != null,
    );
  }

  static const _customAvatarKey = 'custom_avatar';
  static const _avatarBucket = 'avatars';

  static String _avatarPath(String userId) => '$userId/avatar.jpg';

  /// Replaces the reader's picture with [jpeg] (already resized by the
  /// picker). Stored in the public `avatars` bucket under their own folder
  /// (see supabase/avatars.sql) and remembered on the profile, so every
  /// device shows it. Returns false if it did not land.
  static Future<bool> setAvatar(Uint8List jpeg) async {
    final current = user.value;
    if (!_initialised || current == null) return false;
    try {
      final client = Supabase.instance.client;
      final path = _avatarPath(current.id);
      await client.storage
          .from(_avatarBucket)
          .uploadBinary(
            path,
            jpeg,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      // The path never changes, so the version busts every image cache.
      final url =
          '${client.storage.from(_avatarBucket).getPublicUrl(path)}'
          '?v=${DateTime.now().millisecondsSinceEpoch}';
      final res = await client.auth.updateUser(
        UserAttributes(data: {_customAvatarKey: url}),
      );
      _adopt(res.user);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Goes back to the provider's picture (or initials).
  static Future<bool> clearAvatar() async {
    final current = user.value;
    if (!_initialised || current == null) return false;
    try {
      final client = Supabase.instance.client;
      final res = await client.auth.updateUser(
        UserAttributes(data: {_customAvatarKey: null}),
      );
      _adopt(res.user);
      await _removeAvatarFile(current.id);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _removeAvatarFile(String userId) async {
    try {
      await Supabase.instance.client.storage.from(_avatarBucket).remove([
        _avatarPath(userId),
      ]);
    } catch (_) {
      // A leftover file is harmless; nothing points at it any more.
    }
  }

  /// Opens the chosen provider's sign-in. Returns false if it was cancelled or
  /// failed, so the caller can stay silent rather than claiming success.
  static Future<bool> signInWith(SignInProvider provider) async {
    if (!isConfigured) return false;
    await init();
    if (provider == SignInProvider.apple &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS) {
      return _signInWithAppleNatively();
    }
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

  /// Sign in with Apple through the system sheet (Face ID / passcode), the
  /// way App Review expects on iPhone, then hands Apple's identity token to
  /// Supabase. Needs no Services ID or signing key: Supabase checks the token
  /// against the app's bundle id, listed under the Apple provider's Client IDs.
  ///
  /// The nonce ties the token to this one request: Apple signs its SHA-256,
  /// Supabase is given the raw value and checks they match, so a token lifted
  /// from elsewhere cannot be replayed.
  static Future<bool> _signInWithAppleNatively() async {
    try {
      final random = Random.secure();
      final rawNonce = base64Url.encode(
        List<int>.generate(32, (_) => random.nextInt(256)),
      );
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: sha256.convert(utf8.encode(rawNonce)).toString(),
      );
      final idToken = credential.identityToken;
      if (idToken == null) return false;
      final auth = Supabase.instance.client.auth;
      await auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      // Apple gives the name only the first time someone signs in, and never
      // inside the token, so it is saved to the profile while it is here.
      final name = [
        credential.givenName,
        credential.familyName,
      ].whereType<String>().where((p) => p.trim().isNotEmpty).join(' ');
      if (name.isNotEmpty) {
        await auth.updateUser(UserAttributes(data: {'full_name': name}));
      }
      return true;
    } catch (_) {
      // Cancelled at the sheet, or the provider is not switched on yet.
      return false;
    }
  }

  /// Deletes the signed-in account for good.
  ///
  /// Clients cannot touch auth.users directly, so this calls the
  /// `delete_own_account` function (see supabase/delete_own_account.sql), which
  /// deletes the caller and only the caller. Returns false if it did not go
  /// through, so the reader is never told their account is gone when it is not.
  static Future<bool> deleteAccount() async {
    if (!_initialised || user.value == null) return false;
    // While still signed in, since the storage policy only lets the owner
    // delete their own picture.
    await _removeAvatarFile(user.value!.id);
    try {
      await Supabase.instance.client.rpc('delete_own_account');
    } catch (_) {
      return false;
    }
    // The session outlives the row, so end it explicitly.
    await signOut();
    return true;
  }

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
