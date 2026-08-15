import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/greeting_cards.dart';
import 'package:salahulddin_azkar/services/section_config.dart';

/// The dashboard governs the cards now. Two things must hold: a shelf that has
/// been emptied does not appear at all, and a key that does not match the app
/// is caught here rather than becoming a switch that silently does nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SectionConfig.settings.value = {};
    SectionConfig.debugSetLoaded(false);
  });

  void configure(Map<String, (bool, int)> rows) {
    SectionConfig.settings.value = {
      for (final e in rows.entries)
        e.key: SectionSetting(
            key: e.key, title: e.key, enabled: e.value.$1, sortOrder: e.value.$2),
    };
    SectionConfig.debugSetLoaded(true);
  }

  test('the SQL has a row for every card, with the key the app looks up', () {
    final sql = File('supabase/card_sections.sql').readAsStringSync();
    for (final card in GreetingCards.all) {
      expect(card.sectionKey, 'card_${card.id}');
      expect(sql, contains("('${card.sectionKey}'"),
          reason: '${card.greeting} has no row to switch it off');
    }
  });

  test('unconfigured shows everything — the config fails open', () {
    for (final shelf in CardShelf.values) {
      expect(GreetingCards.of(shelf), isNotEmpty);
    }
    expect(GreetingCards.shelvesInUse, CardShelf.values);
  });

  test('a hidden card leaves its shelf', () {
    final victim = GreetingCards.all.first;
    configure({
      for (final c in GreetingCards.all)
        c.sectionKey: (c.id != victim.id, GreetingCards.all.indexOf(c)),
    });
    expect(GreetingCards.of(victim.shelf).map((c) => c.id),
        isNot(contains(victim.id)));
  });

  test('the dashboard order is the shelf order', () {
    final daily = GreetingCards.all.where((c) => c.shelf == CardShelf.daily);
    configure({
      // Reversed on purpose.
      for (final (i, c) in daily.toList().reversed.indexed)
        c.sectionKey: (true, i),
      for (final c in GreetingCards.all)
        if (c.shelf != CardShelf.daily)
          c.sectionKey: (true, 900),
    });
    expect(GreetingCards.of(CardShelf.daily).map((c) => c.id).toList(),
        daily.map((c) => c.id).toList().reversed.toList());
  });

  test('an emptied shelf drops out of the home row entirely', () {
    configure({
      for (final c in GreetingCards.all)
        c.sectionKey: (c.shelf != CardShelf.seasonal,
            GreetingCards.all.indexOf(c)),
    });
    expect(GreetingCards.of(CardShelf.seasonal), isEmpty);
    expect(GreetingCards.shelvesInUse, isNot(contains(CardShelf.seasonal)),
        reason: 'a shelf with nothing on it must not offer itself');
  });
}
