import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/screens/my_cards_screen.dart';
import 'package:salahulddin_azkar/services/my_cards_meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A folder of a dozen cards is a folder nobody can find anything in. These
/// hold the ordering, the search and the naming that make it navigable — and
/// that a deleted card does not leave its name behind for the next one.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Never written to; only their names are read.
  File card(int stamp) => File('/tmp/my_cards/card_$stamp.jpg');

  final older = card(1000);
  final middle = card(2000);
  final newest = card(3000);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    MyCardsMeta.debugReset();
  });

  List<File> arrange(List<File> cards,
          {String query = '', String group = '', CardSort sort = CardSort.newest}) =>
      MyCards.arrange(cards, query: query, group: group, sort: sort);

  group('order', () {
    test('newest first by default, oldest on request', () {
      final cards = [middle, older, newest];
      expect(arrange(cards), [newest, middle, older]);
      expect(arrange(cards, sort: CardSort.oldest), [older, middle, newest]);
    });

    test('by name once the cards are named', () async {
      await MyCardsMeta.set(MyCards.nameOf(newest), title: 'ب');
      await MyCardsMeta.set(MyCards.nameOf(older), title: 'أ');

      expect(arrange([newest, older], sort: CardSort.name), [older, newest]);
    });

    test('grouped cards come before the ungrouped ones', () async {
      // Sorting on the raw string would put the empty group first, which is
      // the opposite of what a reader who made groups wants to see.
      await MyCardsMeta.set(MyCards.nameOf(older), group: 'الأعياد');

      expect(arrange([newest, older], sort: CardSort.group), [older, newest]);
    });
  });

  group('finding one', () {
    test('a search matches the name the reader gave it', () async {
      await MyCardsMeta.set(MyCards.nameOf(older), title: 'عيد الفطر');

      expect(arrange([older, newest], query: 'الفطر'), [older]);
      expect(arrange([older, newest], query: 'لا شيء'), isEmpty);
    });

    test('a search matches the group too', () async {
      await MyCardsMeta.set(MyCards.nameOf(middle), group: 'الأعياد');
      expect(arrange([middle, newest], query: 'الأعياد'), [middle]);
    });

    test('a group filter narrows to that group, and searching stays inside it',
        () async {
      await MyCardsMeta.set(MyCards.nameOf(older),
          title: 'تهنئة', group: 'الأعياد');
      await MyCardsMeta.set(MyCards.nameOf(middle),
          title: 'تهنئة', group: 'المناسبات');

      expect(arrange([older, middle], group: 'الأعياد'), [older]);
      expect(arrange([older, middle], group: 'الأعياد', query: 'تهنئة'),
          [older]);
    });

    test('the filter row offers only groups actually in use', () async {
      expect(MyCardsMeta.groups(), isEmpty);
      await MyCardsMeta.set(MyCards.nameOf(older), group: 'الأعياد');
      await MyCardsMeta.set(MyCards.nameOf(middle), group: 'الأعياد');
      expect(MyCardsMeta.groups(), ['الأعياد']);
    });
  });

  group('names', () {
    test('an unnamed card shows the day it was added, never its file name', () {
      final label = MyCards.labelFor(older);
      expect(label, isNot(contains('card_')));
      expect(label, contains('1970'));
    });

    test('a name survives the next run', () async {
      await MyCardsMeta.set(MyCards.nameOf(older), title: 'عيد');
      await MyCardsMeta.load();
      expect(MyCards.labelFor(older), 'عيد');
    });

    test('a deleted card does not leave its name to the next one', () async {
      await MyCardsMeta.set(MyCards.nameOf(older), title: 'عيد');
      await MyCardsMeta.forget(MyCards.nameOf(older));
      expect(MyCardsMeta.titleOf(MyCards.nameOf(older)), '');
    });
  });

  group('how many across', () {
    test('two by default, and the choice is remembered', () async {
      expect(MyCardsMeta.columns.value, 2);

      await MyCardsMeta.setColumns(4);
      MyCardsMeta.debugReset();
      expect(MyCardsMeta.columns.value, 2);

      await MyCardsMeta.load();
      expect(MyCardsMeta.columns.value, 4);
    });

    test('a count the grid does not offer is refused', () async {
      await MyCardsMeta.setColumns(11);
      expect(MyCardsMeta.columns.value, 2,
          reason: 'eleven cards across a phone is not a grid');
    });

    test('a stored count outside the choices reads as the default', () async {
      SharedPreferences.setMockInitialValues({'@noor_my_cards_columns': 40});
      await MyCardsMeta.load();
      expect(MyCardsMeta.columns.value, 2);
    });

    test('the choices run from a card you can see to a contact sheet', () {
      expect(MyCardsMeta.columnChoices.first, 2);
      expect(MyCardsMeta.columnChoices.last, greaterThan(2));
    });
  });

  group('pictures filed on a shelf', () {
    test('a picture remembers its shelf and what the app does with it',
        () async {
      final name = MyCards.nameOf(older);

      await MyCardsMeta.set(name, shelf: 'seasonal', style: CardStyle.asIs);
      expect(MyCardsMeta.shelfOf(name), 'seasonal');
      expect(MyCardsMeta.styleOf(name), CardStyle.asIs);

      await MyCardsMeta.load();
      expect(MyCardsMeta.shelfOf(name), 'seasonal',
          reason: 'it must still be on that shelf next time');
      expect(MyCardsMeta.styleOf(name), CardStyle.asIs);
    });

    test('a picture with no shelf belongs to the reader\'s own folder', () {
      expect(MyCardsMeta.shelfOf(MyCards.nameOf(newest)), '');
      expect(MyCardsMeta.styleOf(MyCards.nameOf(newest)), CardStyle.background,
          reason: 'written on is the sane default for a plain photograph');
    });

    test('the two styles are distinct and each explains itself', () {
      expect(CardStyle.values, hasLength(2));
      for (final style in CardStyle.values) {
        expect(style.label.trim(), isNotEmpty);
        expect(style.note.trim(), isNotEmpty);
      }
      expect(CardStyle.byId('nothing-like-this'), CardStyle.background);
    });

    test('deleting a picture forgets its shelf too', () async {
      final name = MyCards.nameOf(middle);
      await MyCardsMeta.set(name, shelf: 'daily', style: CardStyle.asIs);
      await MyCardsMeta.forget(name);

      expect(MyCardsMeta.shelfOf(name), '');
      expect(MyCardsMeta.styleOf(name), CardStyle.background,
          reason: 'a deleted picture must not leave a style behind');
    });
  });
}
