import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the cards are laid out and sorted.
enum CardSort {
  newest('الأحدث أولاً'),
  oldest('الأقدم أولاً'),
  name('حسب الاسم'),
  group('حسب المجموعة');

  final String label;
  const CardSort(this.label);
}

/// The names and groups the reader gives their own cards.
///
/// The pictures themselves stay plain files in the app's folder — renaming
/// them would break a card that is open, and a file name cannot hold a group.
/// So a small record sits beside them, keyed by file name: a title to search
/// by, and a group to gather by. A card with no record is still a card; it
/// simply shows its date and sits in "بلا مجموعة".
class MyCardsMeta {
  static const _key = '@noor_my_cards_meta';

  /// Bumped on every change, so an open screen re-reads without being told.
  static final revision = ValueNotifier<int>(0);

  static Map<String, _Entry> _entries = {};

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _entries = {
        for (final e in decoded.entries)
          e.key: _Entry.fromJson(e.value as Map<String, dynamic>),
      };
    } catch (_) {
      // A card without a name is still usable; an unreadable record is not
      // worth refusing to open the folder over.
    }
  }

  static String titleOf(String fileName) => _entries[fileName]?.title ?? '';

  static String groupOf(String fileName) => _entries[fileName]?.group ?? '';

  /// Every group in use, sorted, so the filter row and the picker offer what
  /// the reader has already created rather than a list written here.
  static List<String> groups() {
    final all = _entries.values
        .map((e) => e.group)
        .where((g) => g.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return all;
  }

  static Future<void> set(String fileName,
      {String? title, String? group}) async {
    final current = _entries[fileName] ?? const _Entry(title: '', group: '');
    _entries[fileName] = _Entry(
      title: (title ?? current.title).trim(),
      group: (group ?? current.group).trim(),
    );
    await _save();
  }

  /// Called when a card is deleted, so its name does not outlive it and come
  /// back attached to a different picture that happens to reuse the name.
  static Future<void> forget(String fileName) async {
    if (_entries.remove(fileName) == null) return;
    await _save();
  }

  static Future<void> _save() async {
    revision.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          for (final e in _entries.entries) e.key: e.value.toJson(),
        }),
      );
    } catch (_) {
      // The names still apply for this session.
    }
  }

  @visibleForTesting
  static void debugReset() {
    _entries = {};
    revision.value = 0;
  }
}

class _Entry {
  final String title;
  final String group;

  const _Entry({required this.title, required this.group});

  Map<String, dynamic> toJson() => {'t': title, 'g': group};

  factory _Entry.fromJson(Map<String, dynamic> j) =>
      _Entry(title: j['t'] as String? ?? '', group: j['g'] as String? ?? '');
}
