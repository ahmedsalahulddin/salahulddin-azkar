import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// One card in the hidden personal-duas section — a title and the duas
/// under it, each just a line of text (no citation is required here, unlike
/// the public Adhkar/Hisn content).
class PersonalDuaCategory {
  final String id;
  final String title;
  final String icon;
  final List<String> duas;

  const PersonalDuaCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.duas,
  });

  PersonalDuaCategory copyWith({
    String? title,
    String? icon,
    List<String>? duas,
  }) => PersonalDuaCategory(
    id: id,
    title: title ?? this.title,
    icon: icon ?? this.icon,
    duas: duas ?? this.duas,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'icon': icon,
    'duas': duas,
  };

  factory PersonalDuaCategory.fromJson(Map<String, dynamic> j) =>
      PersonalDuaCategory(
        id: j['id'] as String,
        title: j['title'] as String,
        icon: j['icon'] as String? ?? '🤲',
        duas: (j['duas'] as List).map((e) => e as String).toList(),
      );
}

/// A reader granted access to the admin's personal dua collection.
class PersonalDuaGrant {
  final String userId;
  final String? email;
  final DateTime grantedAt;

  const PersonalDuaGrant({
    required this.userId,
    this.email,
    required this.grantedAt,
  });

  factory PersonalDuaGrant.fromJson(Map<String, dynamic> j) => PersonalDuaGrant(
    userId: j['user_id'] as String,
    email: j['email'] as String?,
    grantedAt: DateTime.parse(j['granted_at'] as String),
  );
}

/// A private, admin-owned dua collection — never bundled with the app,
/// never shown to a general reader. Visible only to the admin themselves
/// (see [AdminScreen]) and to whichever specific readers the admin grants,
/// by email, via [grant]. All server traffic assumes a signed-in reader.
class PersonalDuasService {
  static Future<SupabaseClient> get _client async {
    await AuthService.init();
    return Supabase.instance.client;
  }

  static Never _throw(Object e) {
    throw StateError(e.toString());
  }

  /// The raw stored content visible to the signed-in reader under RLS — the
  /// admin's own collection if they are the admin, or whichever admin's
  /// collection they were granted. Null if nothing is visible or nothing
  /// saved yet.
  static Future<String?> _rawContent() async {
    try {
      final c = await _client;
      final rows = await c.from('personal_duas').select('content').limit(1);
      if (rows.isEmpty) return null;
      return rows.first['content'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _saveRaw(String content) async {
    try {
      final c = await _client;
      final uid = c.auth.currentUser!.id;
      await c.from('personal_duas').upsert({
        'owner_id': uid,
        'content': content,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      _throw(e);
    }
  }

  /// The reader's categories, parsed — or null if nothing is visible/saved
  /// (a blank section, not a stored-but-empty one, reads the same way).
  static Future<List<PersonalDuaCategory>?> categories() async {
    final raw = await _rawContent();
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => PersonalDuaCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveCategories(List<PersonalDuaCategory> cats) async {
    await _saveRaw(jsonEncode(cats.map((c) => c.toJson()).toList()));
  }

  static Future<List<PersonalDuaGrant>> grants() async {
    try {
      final c = await _client;
      final rows = await c
          .from('personal_dua_grants')
          .select()
          .order('granted_at', ascending: false);
      return rows.map((r) => PersonalDuaGrant.fromJson(r)).toList();
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> grant(String email) async {
    try {
      final c = await _client;
      await c.rpc('grant_personal_dua_access', params: {'p_email': email});
    } catch (e) {
      _throw(e);
    }
  }

  static Future<void> revoke(String userId) async {
    try {
      final c = await _client;
      await c.rpc('revoke_personal_dua_access', params: {'p_user_id': userId});
    } catch (e) {
      _throw(e);
    }
  }
}
