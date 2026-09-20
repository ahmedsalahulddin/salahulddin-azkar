import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'sync_service.dart';

class StorageService {
  static const _favoritesKey = '@noor_favorites';
  static const _fontSizeKey = '@noor_font_size';
  static const _tasbihKey = '@noor_tasbih';
  static const _lastSurahKey = '@noor_last_surah';
  static const _lastMushafPageKey = '@noor_last_mushaf_page';

  // ===== المفضلة =====

  /// Bumped whenever the favourites change.
  ///
  /// The favourites tab lives inside an IndexedStack, so it stays alive and is
  /// never rebuilt when you switch back to it — without this it would keep
  /// showing whatever it loaded at launch.
  static final favouritesRevision = ValueNotifier<int>(0);

  static Future<List<String>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_favoritesKey) ?? [];
  }

  /// Toggles, and tells the account when something was removed — a merge
  /// unions the two sides, so a deletion left behind would simply return.
  static Future<bool> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final favs = prefs.getStringList(_favoritesKey) ?? [];
    final added = !favs.contains(id);
    added ? favs.add(id) : favs.remove(id);
    await prefs.setStringList(_favoritesKey, favs);
    if (!favs.contains(id)) {
      unawaited(SyncService.forget(SyncKind.favourite, id));
    }
    favouritesRevision.value++;
    return added;
  }

  static Future<bool> isFavorite(String id) async {
    final favs = await getFavorites();
    return favs.contains(id);
  }

  // ===== حجم الخط =====
  static Future<String> getFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fontSizeKey) ?? 'medium';
  }

  static Future<void> setFontSize(String size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontSizeKey, size);
  }

  // ===== عداد التسبيح =====
  static Future<int> getTasbihCount(String dhikrId) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_tasbihKey);
    if (data == null) return 0;
    final counts = jsonDecode(data) as Map<String, dynamic>;
    return (counts[dhikrId] as int?) ?? 0;
  }

  static Future<void> saveTasbihCount(String dhikrId, int count) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_tasbihKey);
    final counts = data != null
        ? jsonDecode(data) as Map<String, dynamic>
        : <String, dynamic>{};
    counts[dhikrId] = count;
    await prefs.setString(_tasbihKey, jsonEncode(counts));
  }

  // ===== آخر سورة مقروءة =====
  static Future<int?> getLastSurah() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastSurahKey);
  }

  static Future<void> setLastSurah(int number) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSurahKey, number);
  }

  // ===== آخر صفحة في المصحف =====
  static Future<int?> getLastMushafPage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_lastMushafPageKey);
  }

  static Future<void> setLastMushafPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastMushafPageKey, page);
  }
}
