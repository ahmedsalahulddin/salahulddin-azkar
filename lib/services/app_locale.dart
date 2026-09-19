import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide display language. Arabic is the language of record; English was
/// the first addition and kept its own boolean for the many call sites that
/// only ever needed a yes/no on it. Eight more languages sit alongside them,
/// covering the app's general UI chrome — Tahfeez and Account keep their own
/// separate language choice, since a circle or a settings screen may be read
/// in a language that has nothing to do with what the rest of the app shows.
/// Persisted across sessions.
class AppLocale {
  AppLocale._();

  static const _key = '@noor_locale';

  static const languages = <(String code, String name)>[
    ('ar', 'العربية'),
    ('en', 'English'),
    ('fr', 'Français'),
    ('ur', 'اردو'),
    ('id', 'Indonesia'),
    ('ms', 'Bahasa Melayu'),
    ('hi', 'हिन्दी'),
    ('tr', 'Türkçe'),
    ('bn', 'বাংলা'),
    ('ha', 'Hausa'),
  ];

  static final locale = ValueNotifier<String>('ar');

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      if (saved != null && languages.any((l) => l.$1 == saved)) {
        locale.value = saved;
      }
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

  static String get code => locale.value;

  static bool get isRtl => code == 'ar' || code == 'ur';

  static TextDirection get direction =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  static String nameOf(String c) {
    for (final (code, name) in languages) {
      if (code == c) return name;
    }
    return c;
  }
}
