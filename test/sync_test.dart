import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  test('the three kinds are distinct and stable', () {
    // These strings are written into rows; changing one orphans real data.
    expect(SyncKind.bookmark.id, 'bookmark');
    expect(SyncKind.favourite.id, 'favourite');
    expect(SyncKind.position.id, 'position');
    expect(SyncKind.values.map((k) => k.id).toSet().length, 3);
  });
}
