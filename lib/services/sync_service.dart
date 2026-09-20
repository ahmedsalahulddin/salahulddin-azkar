import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_service.dart';
import 'bookmark_service.dart';
import 'storage_service.dart';

/// What a reader accumulates and would hate to lose: bookmarks, notes,
/// favourite adhkar, and the page they had reached.
enum SyncKind {
  bookmark('bookmark'),
  favourite('favourite'),
  position('position');

  const SyncKind(this.id);

  final String id;
}

/// Carries reading state between a reader's devices.
///
/// Three rules hold this together, and each exists because the obvious
/// alternative loses someone's work:
///
/// **The device stays the source of truth.** Everything is written locally
/// first and uploaded after. A reader with no signal, no account, or no
/// interest in one loses nothing and notices nothing.
///
/// **Merge, never replace.** Sync unions the two sides rather than letting
/// either win. A phone that has been offline for a month is not stale — it is
/// holding a month of bookmarks nobody else has.
///
/// **A deletion is not a disagreement.** Because merging unions, an item
/// deleted on one device would return from the other. Deletions are therefore
/// sent immediately while the app has the reader's attention, rather than
/// inferred later from an absence.
class SyncService {
  static const _table = 'reader_state';

  /// Null when nothing has synced yet. Shown so the reader can tell whether
  /// their notes are actually anywhere but here.
  static final lastSynced = ValueNotifier<DateTime?>(null);

  static final syncing = ValueNotifier<bool>(false);

  /// Sync needs somebody to sync for; a guest is a perfectly good state.
  static bool get available =>
      AuthService.isConfigured && AuthService.user.value != null;

  static SupabaseClient get _client => Supabase.instance.client;
  static String? get _uid => Supabase.instance.client.auth.currentUser?.id;

  /// Starts syncing whenever an account appears, and once at launch.
  ///
  /// Waiting for a button meant a reader could sign in on a second phone, see
  /// none of their bookmarks, and reasonably conclude the feature did not
  /// work — which is what happened.
  static void watch() {
    AuthService.user.addListener(() {
      if (AuthService.user.value != null) sync();
    });
    if (available) sync();
  }

  /// Pulls the account's state, merges it into this device, and pushes back
  /// whatever the account was missing.
  ///
  /// Returns false when it could not run or did not finish, so the caller can
  /// say so rather than showing a tick over nothing.
  static Future<bool> sync() async {
    if (!available || syncing.value) return false;
    syncing.value = true;
    try {
      await AuthService.init();
      final uid = _uid;
      if (uid == null) return false;

      final rows =
          (await _client
                      .from(_table)
                      .select('kind, key, value')
                      .eq('user_id', uid)
                  as List)
              .cast<Map<String, dynamic>>();

      final favourites = <String>{};
      final bookmarks = <String, Map<String, dynamic>>{};
      String? remotePosition;
      for (final row in rows) {
        final kind = row['kind'] as String;
        final key = row['key'] as String;
        if (kind == SyncKind.favourite.id) favourites.add(key);
        if (kind == SyncKind.bookmark.id) {
          bookmarks[key] = ((row['value'] as Map?) ?? {})
              .cast<String, dynamic>();
        }
        if (kind == SyncKind.position.id) {
          remotePosition = (row['value'] as Map?)?['page']?.toString();
        }
      }

      await _mergeFavourites(uid, favourites);
      await _mergeBookmarks(uid, bookmarks);
      await _mergePosition(uid, remotePosition);

      lastSynced.value = DateTime.now();
      return true;
    } catch (_) {
      // Sync is a convenience; failing it must never cost the reader anything
      // they have locally, and never interrupt them.
      return false;
    } finally {
      syncing.value = false;
    }
  }

  static Future<void> _mergeFavourites(String uid, Set<String> remote) async {
    final local = (await StorageService.getFavorites()).toSet();

    for (final id in remote.difference(local)) {
      await StorageService.toggleFavorite(id);
    }
    await _upload(uid, SyncKind.favourite, local.difference(remote));
  }

  static Future<void> _mergeBookmarks(
    String uid,
    Map<String, Map<String, dynamic>> remote,
  ) async {
    final local = await BookmarkService.all();
    final localKeys = {for (final b in local) b.key};

    // Rebuilt from the row's own payload, not from its key: a bookmark carries
    // a page and possibly a note, and a key holds neither. A row written by an
    // older build has no payload — those stay uploaded but unrestored rather
    // than being reconstructed out of guesses.
    final restored = <Bookmark>[];
    for (final entry in remote.entries) {
      if (localKeys.contains(entry.key) || entry.value.isEmpty) continue;
      try {
        restored.add(Bookmark.fromJson(entry.value));
      } catch (_) {
        // A malformed row is skipped, never allowed to fail the whole sync.
      }
    }
    if (restored.isNotEmpty) {
      await BookmarkService.replaceAll([...local, ...restored]);
    }

    // Upload with the whole bookmark, so the device that reads this next can
    // rebuild it properly.
    await _uploadBookmarks(
      uid,
      local.where((b) => !remote.containsKey(b.key)).toList(),
    );
  }

  static Future<void> _uploadBookmarks(
    String uid,
    List<Bookmark> bookmarks,
  ) async {
    if (bookmarks.isEmpty) return;
    await _client.from(_table).upsert([
      for (final bookmark in bookmarks)
        {
          'user_id': uid,
          'kind': SyncKind.bookmark.id,
          'key': bookmark.key,
          'value': bookmark.toJson(),
          'updated_at': DateTime.now().toIso8601String(),
        },
    ]);
  }

  static Future<void> _mergePosition(String uid, String? remotePage) async {
    final localPage = await StorageService.getLastMushafPage();
    final remote = int.tryParse(remotePage ?? '');

    // The furthest page wins. Two devices reading the same Mushaf are one
    // reader, and going backwards is the only outcome they would notice.
    final furthest = [localPage, remote].whereType<int>().fold<int?>(
      null,
      (best, page) => best == null || page > best ? page : best,
    );
    if (furthest == null) return;

    if (furthest != localPage) {
      await StorageService.setLastMushafPage(furthest);
    }
    if (furthest != remote) {
      await _client.from(_table).upsert({
        'user_id': uid,
        'kind': SyncKind.position.id,
        'key': 'mushaf',
        'value': {'page': furthest},
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  static Future<void> _upload(
    String uid,
    SyncKind kind,
    Set<String> keys,
  ) async {
    if (keys.isEmpty) return;
    await _client.from(_table).upsert([
      for (final key in keys)
        {
          'user_id': uid,
          'kind': kind.id,
          'key': key,
          'updated_at': DateTime.now().toIso8601String(),
        },
    ]);
  }

  /// Removes one item from the account.
  ///
  /// Called the moment something is deleted locally. Because merging unions
  /// the two sides, an item left on the server would come back on the next
  /// sync — so a deletion has to travel immediately or it does not travel at
  /// all.
  static Future<void> forget(SyncKind kind, String key) async {
    if (!available) return;
    try {
      final uid = _uid;
      if (uid == null) return;
      await _client
          .from(_table)
          .delete()
          .eq('user_id', uid)
          .eq('kind', kind.id)
          .eq('key', key);
    } catch (_) {
      // The local deletion already happened; this is the copy that lags.
    }
  }
}
