import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/greeting_cards.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/widgets/greeting_card_view.dart';

/// A card is a fixed shape carrying a verse of unknown length, and it is going
/// to be sent to someone. Both halves of that sentence are load-bearing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the catalogue', () {
    test('ids are unique and every shelf has cards on it', () {
      expect(GreetingCards.all.map((c) => c.id).toSet().length,
          GreetingCards.all.length);
      for (final shelf in CardShelf.values) {
        expect(GreetingCards.of(shelf), isNotEmpty,
            reason: '${shelf.title} is empty');
      }
    });

    test('the daily shelf is the one pinned first', () {
      expect(CardShelf.values.first, CardShelf.daily);
    });

    test('every card names an ayah that actually exists', () async {
      final index = await QuranService.index();
      final counts = {for (final s in index) s.number: s.ayahCount};

      for (final card in GreetingCards.all) {
        expect(counts.containsKey(card.surah), isTrue,
            reason: '${card.id} points at surah ${card.surah}');
        expect(card.ayah, inInclusiveRange(1, counts[card.surah]!),
            reason: '${card.id} points past the end of its surah');
      }
    });

    test('the verse comes from the Mushaf, not from this file', () async {
      // Typed Arabic does not reliably match the printed edition, so the card
      // must read its text out of the bundle every time.
      for (final card in GreetingCards.all) {
        final resolved = await GreetingCards.resolve(card);
        final surah = await QuranService.surah(card.surah);
        final ayah = surah.ayahs.firstWhere((a) => a.number == card.ayah);
        expect(resolved.verse, ayah.text);
        expect(resolved.citation, contains(QuranService.toArabicDigits(card.ayah)));
      }
    });

    test('every greeting says something', () {
      for (final card in GreetingCards.all) {
        expect(card.greeting.trim(), isNotEmpty);
        expect(card.note?.trim(), isNot(''));
      }
    });
  });

  group('on a card', () {
    testWidgets('every card lays out without overflowing', (tester) async {
      // The narrow case is the grid preview; the wide one is the viewer.
      for (final width in [180.0, 380.0]) {
        for (final card in GreetingCards.all) {
          final resolved = await GreetingCards.resolve(card);
          await tester.pumpWidget(MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Center(
                child: SizedBox(
                  width: width,
                  child: GreetingCardView(resolved: resolved),
                ),
              ),
            ),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull,
              reason: '${card.id} overflowed at ${width}px');
        }
      }
    });

    testWidgets('the card keeps its shape whatever it is given',
        (tester) async {
      final resolved = await GreetingCards.resolve(GreetingCards.all.first);
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: GreetingCardView(resolved: resolved),
          ),
        ),
      ));
      final size = tester.getSize(find.byType(GreetingCardView));
      expect(size.width / size.height,
          closeTo(GreetingCardView.aspectRatio, 0.01));
    });

    testWidgets('the signature and note appear only when given',
        (tester) async {
      final resolved = await GreetingCards.resolve(GreetingCards.all.first);
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 380,
            child: GreetingCardView(
              resolved: resolved,
              senderName: 'أحمد صلاح الدين',
              senderNote: 'كل عام وأنتم بخير يا غالي',
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(find.text('المرسل: أحمد صلاح الدين'), findsOneWidget);
      expect(find.text('كل عام وأنتم بخير يا غالي'), findsOneWidget);

      // Left empty, no stray "المرسل:" label survives.
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 380,
            child: GreetingCardView(resolved: resolved, senderName: '  '),
          ),
        ),
      ));
      await tester.pump();
      expect(find.textContaining('المرسل'), findsNothing);
    });

    testWidgets('the app is named only on the copy that gets sent',
        (tester) async {
      final resolved = await GreetingCards.resolve(GreetingCards.all.first);
      for (final sharing in [false, true]) {
        await tester.pumpWidget(MaterialApp(
          home: Center(
            child: SizedBox(
              width: 380,
              child: GreetingCardView(resolved: resolved, forSharing: sharing),
            ),
          ),
        ));
        await tester.pump();
        expect(find.text('islamic-azkar.yallanow.app'),
            sharing ? findsOneWidget : findsNothing);
      }
    });
  });
}
