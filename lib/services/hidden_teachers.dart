import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Teachers this reader chose not to see in the directory. Kept on the
/// device only: it is the reader's own preference, and nothing the teacher
/// needs to know about. The name is kept beside the id so the list of
/// hidden teachers in Account can show who they are without a fetch.
class HiddenTeachers {
  HiddenTeachers._();

  static const _key = '@noor_hidden_teachers';
  static const _namesKey = '@noor_hidden_teacher_names';

  static final ids = ValueNotifier<Set<String>>({});

  /// Names as they were when hidden; may lack entries hidden before names
  /// were kept.
  static final names = <String, String>{};

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_namesKey);
      if (raw != null) {
        names
          ..clear()
          ..addAll(Map<String, String>.from(jsonDecode(raw) as Map));
      }
      ids.value = (prefs.getStringList(_key) ?? const []).toSet();
    } catch (_) {
      // Nothing hidden, as far as this session knows.
    }
  }

  static Future<void> set(String userId, bool hidden, {String? name}) async {
    final updated = {...ids.value};
    if (hidden) {
      updated.add(userId);
      if (name != null) names[userId] = name;
    } else {
      updated.remove(userId);
      names.remove(userId);
    }
    ids.value = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, updated.toList());
      await prefs.setString(_namesKey, jsonEncode(names));
    } catch (_) {
      // Holds for this session.
    }
  }
}
