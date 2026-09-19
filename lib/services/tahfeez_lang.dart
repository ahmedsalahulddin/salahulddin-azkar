import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';

/// The language the memorisation section is read in — chosen from the top
/// of its tab, independently of the app language, because a circle may be
/// shared by a teacher and students who do not read the same language.
/// Null means "follow the app language".
class TahfeezLang {
  static const _key = 'tahfeez_lang';

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

  static final override = ValueNotifier<String?>(null);

  /// The language actually in effect: the reader's own choice for this
  /// section, or the app's general language if they never set one — now
  /// that both cover the same ten languages, "follow the app" means all of
  /// them, not just English.
  static String get code => override.value ?? AppLocale.code;

  static bool get isRtl => code == 'ar' || code == 'ur';

  static TextDirection get direction =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  static String nameOf(String c) {
    for (final (code, name) in languages) {
      if (code == c) return name;
    }
    return c;
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      override.value = prefs.getString(_key);
    } catch (_) {}
  }

  static Future<void> set(String? c) async {
    override.value = c;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (c == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, c);
      }
    } catch (_) {}
  }
}
