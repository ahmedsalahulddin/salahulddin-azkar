import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/bookmark_service.dart';
import 'package:salahulddin_azkar/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sync touches the one thing a reader would be upset to lose. The rules that
/// protect them are worth pinning even where the network cannot be reached
/// from a test: the local copy always wins its own existence, nothing is
/// attempted without an account, and the SQL that guards the rows says what it
/// is supposed to say.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the rows are private', () {
    late String sql;
    setUpAll(() => sql = File('supabase/sync.sql').readAsStringSync());

    test('row level security is on — without it the policies are decoration',
        () {
      expect(sql, contains('enable row level security'));
    });

    test('every verb is restricted to the row owner', () {
      // A missing policy on any one verb is a hole: select leaks other
      // readers' notes, update and delete let them be altered.
      for (final verb in ['select', 'insert', 'update', 'delete']) {
        expect(sql, contains('for $verb'), reason: '$verb has no policy');
      }
      // Four checks against auth.uid(), one per policy, plus the update's
      // second clause.
      expect('auth.uid() = user_id'.allMatches(sql).length,
          greaterThanOrEqualTo(4));
    });

    test('nothing grants a wider audience', () {
      expect(sql.toLowerCase(), isNot(contains('using (true)')));
      expect(sql.toLowerCase(), isNot(contains('to anon')));
    });

    test('deleting an account takes its rows with it', () {
      expect(sql, contains('on delete cascade'),
          reason: 'notes must not outlive the account they belong to');
    });
  });

  group('without an account', () {
    test('sync does not run, and says so rather than pretending', () async {
      expect(SyncService.available, isFalse);
      expect(await SyncService.sync(), isFalse);
      expect(SyncService.lastSynced.value, isNull,
          reason: 'a sync that never happened must not claim a timestamp');
    });

    test('forgetting an item is harmless with nobody to tell', () async {
      // Called from every local deletion, so it has to be safe for guests.
      await expectLater(
          SyncService.forget(SyncKind.favourite, 'x'), completes);
    });

    test('a guest is never left mid-sync', () async {
      await SyncService.sync();
      expect(SyncService.syncing.value, isFalse);
    });
  });

  group('a bookmark survives the round trip', () {
    test('everything it carries comes back, not just its key', () {
      const original = Bookmark(
        kind: BookmarkKind.memorising,
        surah: 2,
        ayah: 255,
        page: 42,
        note: 'آية الكرسي',
      );

      // This is the whole reason the row carries a payload: a key holds the
      // kind and the position, and nothing else. Page and note would be
      // invented if they were rebuilt from the key alone.
      final restored = Bookmark.fromJson(original.toJson());
      expect(restored.kind, original.kind);
      expect(restored.surah, original.surah);
      expect(restored.ayah, original.ayah);
      expect(restored.page, original.page);
      expect(restored.note, original.note);
      expect(restored.key, original.key);
    });

    test('a bookmark without a note stays without one', () {
      const plain =
          Bookmark(kind: BookmarkKind.reading, surah: 18, ayah: 10, page: 294);
      expect(Bookmark.fromJson(plain.toJson()).note, isNull);
    });

    test('an unknown kind falls back rather than throwing', () {
      // A row written by a newer build must not break an older one's sync.
      final odd = Bookmark.fromJson(
          {'k': 'a-kind-from-the-future', 's': 1, 'a': 1, 'p': 1});
      expect(odd.kind, BookmarkKind.reading);
    });

    test('the key is what the deletion path sends', () {
      const bookmark =
          Bookmark(kind: BookmarkKind.reading, surah: 3, ayah: 7, page: 50);
      // forget() is called with exactly this string; if the two ever drift,
      // deletions stop finding their rows and come back on the next merge.
      expect(bookmark.key, 'reading:3:7');
    });
  });

  test('the three kinds are distinct and stable', () {
    // These strings are written into rows; changing one orphans real data.
    expect(SyncKind.bookmark.id, 'bookmark');
    expect(SyncKind.favourite.id, 'favourite');
    expect(SyncKind.position.id, 'position');
    expect(SyncKind.values.map((k) => k.id).toSet().length, 3);
  });
}
