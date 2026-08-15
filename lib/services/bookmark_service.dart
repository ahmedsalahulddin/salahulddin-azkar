import 'dart:convert';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'sync_service.dart';

enum BookmarkKind {
  reading('القراءة', '📖'),
  memorising('الحفظ', '🧠'),
  note('ملاحظة', '📝');

  final String label;
  final String icon;

  const BookmarkKind(this.label, this.icon);
}

class Bookmark {
  final BookmarkKind kind;
  final int surah;
  final int ayah;
  final int page;
  final String? note;

  const Bookmark({
    required this.kind,
    required this.surah,
    required this.ayah,
    required this.page,
    this.note,
  });

  String get key => '${kind.name}:$surah:$ayah';

  Map<String, dynamic> toJson() => {
        'k': kind.name,
        's': surah,
        'a': ayah,
        'p': page,
        if (note != null) 'n': note,
      };

  factory Bookmark.fromJson(Map<String, dynamic> j) => Bookmark(
        kind: BookmarkKind.values.firstWhere(
          (k) => k.name == j['k'],
          orElse: () => BookmarkKind.reading,
        ),
        surah: j['s'],
        ayah: j['a'],
        page: j['p'],
        note: j['n'],
      );
}

/// Marks placed on ayahs: a reading position, something being memorised, or a
/// note to come back to. Kept separate from the adhkar favourites so the two
/// lists never mix.
class BookmarkService {
  static const _key = '@noor_mushaf_bookmarks';

  static Future<List<Bookmark>> all() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => Bookmark.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<List<Bookmark>> ofKind(BookmarkKind kind) async =>
      (await all()).where((b) => b.kind == kind).toList();

  static Future<bool> exists(BookmarkKind kind, int surah, int ayah) async =>
      (await all()).any(
        (b) => b.kind == kind && b.surah == surah && b.ayah == ayah,
      );

  /// Adds the bookmark, or removes it when the same ayah is already marked with
  /// this kind. Returns true when it ends up marked.
  static Future<bool> toggle(Bookmark bookmark) async {
    final list = await all();
    final index = list.indexWhere((b) => b.key == bookmark.key);

    if (index >= 0 && bookmark.note == null) {
      list.removeAt(index);
      await _save(list);
      // Toggling off is a deletion like any other, and the action bar reaches
      // it this way rather than through remove().
      unawaited(SyncService.forget(SyncKind.bookmark, bookmark.key));
      return false;
    }

    if (index >= 0) {
      list[index] = bookmark; // updating a note keeps the mark in place
    } else {
      list.add(bookmark);
    }
    await _save(list);
    return true;
  }

  /// Removes locally and tells the account, for the same reason favourites do:
  /// a merge unions, so a deletion that stays here comes back from there.
  static Future<void> remove(BookmarkKind kind, int surah, int ayah) async {
    unawaited(SyncService.forget(SyncKind.bookmark, '${kind.name}:$surah:$ayah'));
    final list = await all()
      ..removeWhere(
        (b) => b.kind == kind && b.surah == surah && b.ayah == ayah,
      );
    await _save(list);
  }

  /// Replaces the stored list wholesale. Used by sync after a merge, which is
  /// the only caller that knows about bookmarks it did not create.
  static Future<void> replaceAll(List<Bookmark> list) => _save(list);

  static Future<void> _save(List<Bookmark> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(list.map((b) => b.toJson()).toList()),
    );
  }
}
