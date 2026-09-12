import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide display language. Supports Arabic (default) and English.
/// Persisted across sessions.
class AppLocale {
  AppLocale._();

  static const _key = '@noor_locale';

  static final locale = ValueNotifier<String>('ar');

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved == 'en' || saved == 'ar') locale.value = saved!;
    } catch (_) {}
  }

  static Future<void> set(String code) async {
    locale.value = code;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, code);
    } catch (_) {}
  }

  static bool get isEn => locale.value == 'en';
}
