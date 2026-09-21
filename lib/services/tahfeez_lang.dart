import 'package:flutter/material.dart';

import 'app_locale.dart';

/// The language the memorisation section is read in — the app's own
/// language, same as everywhere else. This used to be its own picker,
/// independent of the app language; it now just mirrors [AppLocale] so the
/// one toggle on the home screen covers the whole app.
class TahfeezLang {
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

  static String get code => AppLocale.code;

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
