import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// One card of duas — a title and the lines under it. Used for both the
/// shared base collection and each reader's own.
class DuaCategory {
  final String id;
  final String title;
  final String icon;
  final List<String> duas;

  const DuaCategory({
    required this.id,
    required this.title,
    required this.icon,
    required this.duas,
  });

  DuaCategory copyWith({String? title, String? icon, List<String>? duas}) =>
      DuaCategory(
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

  factory DuaCategory.fromJson(Map<String, dynamic> j) => DuaCategory(
    id: j['id'] as String,
    title: j['title'] as String,
    icon: j['icon'] as String? ?? '🤲',
    duas: (j['duas'] as List).map((e) => e as String).toList(),
  );
}

/// The shared base collection (every reader sees the same one, admin-edited
/// from its own screen) plus each signed-in reader's own — kept entirely
/// private to them and synced to their account, the same way favourites and
/// bookmarks already are. Guests see the base collection only.
class DuasService {
  static Future<SupabaseClient> get _client async {
    await AuthService.init();
    return Supabase.instance.client;
  }

  static Never _throw(Object e) {
    throw StateError(e.toString());
  }

  static List<DuaCategory> _decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded
          .map((e) => DuaCategory.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String _encode(List<DuaCategory> cats) =>
      jsonEncode(cats.map((c) => c.toJson()).toList());

  /// The base collection, readable by anyone — signed in or not.
  static Future<List<DuaCategory>> base() async {
    try {
      final c = await _client;
      final rows = await c
          .from('duas_base')
          .select('content')
          .eq('id', 1)
          .limit(1);
      if (rows.isEmpty) return const [];
      return _decode(rows.first['content'] as String?);
    } catch (_) {
      return const [];
    }
  }

  /// Admin-only — the write policy on duas_base rejects anyone else.
  static Future<void> saveBase(List<DuaCategory> cats) async {
    try {
      final c = await _client;
      await c.from('duas_base').upsert({
        'id': 1,
        'content': _encode(cats),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      _throw(e);
    }
  }

  /// The signed-in reader's own additions. Empty for a guest — there is
  /// nowhere to sync a guest's additions to, so the caller should prompt
  /// sign-in before offering to add rather than call this.
  static Future<List<DuaCategory>> mine() async {
    if (AuthService.user.value == null) return const [];
    try {
      final c = await _client;
      final uid = c.auth.currentUser!.id;
      final rows = await c
          .from('user_duas')
          .select('content')
          .eq('user_id', uid)
          .limit(1);
      if (rows.isEmpty) return const [];
      return _decode(rows.first['content'] as String?);
    } catch (_) {
      return const [];
    }
  }

  static Future<void> saveMine(List<DuaCategory> cats) async {
    try {
      final c = await _client;
      final uid = c.auth.currentUser!.id;
      await c.from('user_duas').upsert({
        'user_id': uid,
        'content': _encode(cats),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      _throw(e);
    }
  }
}
