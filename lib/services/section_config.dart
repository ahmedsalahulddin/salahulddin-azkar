import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';

/// Whether a home-screen section is shown, and where it sits.
class SectionSetting {
  final String key;
  final String title;
  final bool enabled;
  final int sortOrder;

  const SectionSetting({
    required this.key,
    required this.title,
    required this.enabled,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() =>
      {'key': key, 'title': title, 'enabled': enabled, 'sort_order': sortOrder};

  factory SectionSetting.fromJson(Map<String, dynamic> j) => SectionSetting(
        key: j['key'],
        title: j['title'] ?? j['key'],
        enabled: j['enabled'] ?? true,
        sortOrder: j['sort_order'] ?? 0,
      );

  SectionSetting copyWith({bool? enabled, int? sortOrder}) => SectionSetting(
        key: key,
        title: title,
        enabled: enabled ?? this.enabled,
        sortOrder: sortOrder ?? this.sortOrder,
      );
}

/// Lets the home screen be rearranged without shipping a new build.
///
/// **This service fails open.** If the network is down, the project is
/// unreachable, or the response is malformed, every section stays visible in
/// its built-in order. A section disappears only on an explicit, successful
/// instruction to hide it — a config service that can empty the app when it
/// goes down is worse than having none.
class SectionConfig {
  static const _cacheKey = '@noor_section_config';

  /// Rebuilt-on-change so the home screen reacts as soon as settings arrive.
  static final settings = ValueNotifier<Map<String, SectionSetting>>({});

  /// True once a real answer has been seen, from the network or the cache.
  static bool _loaded = false;

  /// Reads the cache immediately, then refreshes from the project in the
  /// background — the home screen never waits on the network to paint.
  static Future<void> load() async {
    await _loadCache();
    unawaitedRefresh();
  }

  static Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      _apply((jsonDecode(raw) as List).cast<Map<String, dynamic>>());
      _loaded = true;
    } catch (_) {
      // A corrupt cache must not keep sections hidden.
    }
  }

  static void unawaitedRefresh() {
    // Deliberately not awaited: a slow project must not delay the first frame.
    refresh();
  }

  static Future<void> refresh() async {
    if (!AuthService.isConfigured) return;
    try {
      await AuthService.init();
      final rows = await Supabase.instance.client
          .from('app_sections')
          .select()
          .order('sort_order');

      final list = (rows as List).cast<Map<String, dynamic>>();
      if (list.isEmpty) return; // an empty table is not an instruction to hide

      _apply(list);
      _loaded = true;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(list));
    } catch (_) {
      // Leave whatever is already in place. Silence here is the safe answer.
    }
  }

  static void _apply(List<Map<String, dynamic>> rows) {
    settings.value = {
      for (final row in rows)
        row['key'] as String: SectionSetting.fromJson(row),
    };
    // A frame the reader is using may have just been hidden.
    onApplied?.call();
  }

  /// Run after every successful config load. Set at startup rather than
  /// imported, so this service keeps knowing nothing about what reads it.
  static void Function()? onApplied;

  /// Whether [key] should appear. Unknown sections and an unloaded config both
  /// answer yes.
  static bool isVisible(String key) {
    if (!_loaded) return true;
    return settings.value[key]?.enabled ?? true;
  }

  /// Lets tests stand in for a config that has, or has not, arrived.
  @visibleForTesting
  static void debugSetLoaded(bool value) => _loaded = value;

  /// Sort position for [key]; unknown sections keep their built-in order by
  /// sorting last but stable.
  static int orderOf(String key, int fallback) =>
      settings.value[key]?.sortOrder ?? fallback;

  // ---- admin ------------------------------------------------------------

  static Future<bool> isAdmin() async {
    if (!AuthService.isConfigured || AuthService.user.value == null) {
      return false;
    }
    try {
      await AuthService.init();
      final result = await Supabase.instance.client.rpc('is_admin');
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Saves visibility and order. Returns false if the write did not land, so
  /// the caller can say so instead of showing a change that did not happen.
  static Future<bool> save(List<SectionSetting> updated) async {
    if (!AuthService.isConfigured) return false;
    try {
      await AuthService.init();
      final client = Supabase.instance.client;
      for (var i = 0; i < updated.length; i++) {
        final s = updated[i];
        await client
            .from('app_sections')
            .update({'enabled': s.enabled, 'sort_order': i + 1})
            .eq('key', s.key);
      }
      await refresh();
      return true;
    } catch (_) {
      return false;
    }
  }
}
