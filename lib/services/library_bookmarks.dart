import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Marks a reading position inside a library book — a chapter or hadith the
/// reader wants to find again, in a book with no ayah numbers to bookmark by.
class LibraryBookmarks {
  LibraryBookmarks._();

  static const _key = '@noor_library_bookmarks';

  /// "$bookId:$number" for every marked entry, loaded once at startup.
  static final marks = ValueNotifier<Set<String>>({});

  static String _of(String bookId, int number) => '$bookId:$number';

  static bool has(String bookId, int number) =>
      marks.value.contains(_of(bookId, number));

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      marks.value = (prefs.getStringList(_key) ?? const []).toSet();
    } catch (_) {
      // Starts empty; nothing was marked yet as far as this session knows.
    }
  }

  static Future<void> toggle(String bookId, int number) async {
    final key = _of(bookId, number);
    final updated = {...marks.value};
    if (!updated.remove(key)) updated.add(key);
    marks.value = updated;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, updated.toList());
    } catch (_) {
      // The mark still holds for this session.
    }
  }
}
