import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Teachers this reader chose not to see in the directory. Kept on the
/// device only: it is the reader's own preference, and nothing the teacher
/// needs to know about.
class HiddenTeachers {
  HiddenTeachers._();

  static const _key = '@noor_hidden_teachers';

  static final ids = ValueNotifier<Set<String>>({});

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      ids.value = (prefs.getStringList(_key) ?? const []).toSet();
    } catch (_) {
      // Nothing hidden, as far as this session knows.
    }
  }

  static Future<void> set(String userId, bool hidden) async {
    final updated = {...ids.value};
    if (hidden) {
      updated.add(userId);
    } else {
      updated.remove(userId);
    }
    ids.value = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, updated.toList());
    } catch (_) {
      // Holds for this session.
    }
  }
}
