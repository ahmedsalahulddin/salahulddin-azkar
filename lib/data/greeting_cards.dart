import 'package:flutter/material.dart';

import '../services/section_config.dart';
import '../widgets/mushaf_frames.dart';
import 'quran_data.dart';

/// The three shelves of cards.
enum CardShelf {
  daily('daily', '🌤️', 'كروت يومية', 'صباح ومساء وجمعة'),
  seasonal('seasonal', '🌙', 'كروت موسمية', 'رمضان والعيدان والحج'),
  special('special', '🎁', 'كروت خاصة', 'مولود وشفاء وزواج وتعزية');

  const CardShelf(this.id, this.icon, this.title, this.subtitle);

  final String id;
  final String icon;
  final String title;
  final String subtitle;
}

/// Paper and ink for a card. Kept apart from the Mushaf's papers: a card is
/// meant to be sent, so it can carry colour a page of Qur'an should not.
enum CardPalette {
  gold('ذهبي', Color(0xFF14110A), Color(0xFF1E1A0E), Color(0xFFD4A843)),
  emerald('زمردي', Color(0xFF07160F), Color(0xFF0C2419), Color(0xFF3FBE84)),
  night('ليلي', Color(0xFF080C18), Color(0xFF101833), Color(0xFF9FB4E8)),
  rose('وردي', Color(0xFF17090F), Color(0xFF25121B), Color(0xFFE0A0B8)),
  sand('رملي', Color(0xFFF6EEDD), Color(0xFFEADCC0), Color(0xFF8B6508));

  const CardPalette(this.label, this.top, this.bottom, this.ink);

  final String label;

  /// The card's ground, top to bottom.
  final Color top;
  final Color bottom;

  /// Ornament and headline.
  final Color ink;

  /// True when the ground is light, so the body text has to darken.
  bool get isLight => this == CardPalette.sand;

  Color get body => isLight ? const Color(0xFF2A2114) : const Color(0xFFF2ECDE);
  Color get muted =>
      isLight ? const Color(0xFF7A6743) : const Color(0xFFA4977C);
}

/// One card: a greeting, and something from the Book underneath it.
class GreetingCard {
  final String id;
  final CardShelf shelf;

  /// The line across the top — what the sender is actually saying.
  final String greeting;

  /// A second, quieter line. Optional.
  final String? note;

  /// Where the body comes from. Read out of the bundled Mushaf rather than
  /// typed here: hand-typed Arabic does not reliably come back as the same
  /// code points, and a verse being sent to someone is no place to be
  /// approximate about that.
  final int surah;
  final int ayah;

  final CardPalette palette;
  final MushafFrame frame;

  /// The key this card answers to in app_sections.
  String get sectionKey => 'card_$id';

  const GreetingCard({
    required this.id,
    required this.shelf,
    required this.greeting,
    required this.surah,
    required this.ayah,
    required this.palette,
    required this.frame,
    this.note,
  });
}

/// A card with its verse and citation resolved.
class ResolvedCard {
  final GreetingCard card;
  final String verse;
  final String citation;

  const ResolvedCard({
    required this.card,
    required this.verse,
    required this.citation,
  });
}

class GreetingCards {
  static const all = <GreetingCard>[
    // ---- يومية ----------------------------------------------------------
    GreetingCard(
      id: 'morning',
      shelf: CardShelf.daily,
      greeting: 'صَبَاحُ الخَيْرِ',
      note: 'أسعد الله صباحك',
      surah: 30,
      ayah: 17,
      palette: CardPalette.gold,
      frame: MushafFrame.filigree,
    ),
    GreetingCard(
      id: 'evening',
      shelf: CardShelf.daily,
      greeting: 'مَسَاءُ الخَيْرِ',
      note: 'طاب مساؤك',
      surah: 13,
      ayah: 28,
      palette: CardPalette.night,
      frame: MushafFrame.stars,
    ),
    GreetingCard(
      id: 'friday',
      shelf: CardShelf.daily,
      greeting: 'جُمُعَةٌ مُبَارَكَة',
      note: 'أكثروا من الصلاة على النبي ﷺ',
      surah: 62,
      ayah: 9,
      palette: CardPalette.emerald,
      frame: MushafFrame.arabesque,
    ),
    GreetingCard(
      id: 'reminder',
      shelf: CardShelf.daily,
      greeting: 'ذَكِّرْ',
      note: 'فإن الذكرى تنفع المؤمنين',
      surah: 33,
      ayah: 41,
      palette: CardPalette.sand,
      frame: MushafFrame.madinah,
    ),
    GreetingCard(
      id: 'goodnight',
      shelf: CardShelf.daily,
      greeting: 'تُصْبِحُ عَلَى خَيْر',
      note: 'باسمك اللهم أحيا وأموت',
      surah: 78,
      ayah: 9,
      palette: CardPalette.night,
      frame: MushafFrame.rosette,
    ),
    GreetingCard(
      id: 'dua',
      shelf: CardShelf.daily,
      greeting: 'دُعَاءٌ لَكَ',
      surah: 2,
      ayah: 201,
      palette: CardPalette.gold,
      frame: MushafFrame.interlace,
    ),

    // ---- موسمية ---------------------------------------------------------
    GreetingCard(
      id: 'ramadan',
      shelf: CardShelf.seasonal,
      greeting: 'رَمَضَانُ مُبَارَك',
      note: 'بلغكم الله صيامه وقيامه',
      surah: 2,
      ayah: 186,
      palette: CardPalette.emerald,
      frame: MushafFrame.filigree,
    ),
    GreetingCard(
      id: 'laylat-alqadr',
      shelf: CardShelf.seasonal,
      greeting: 'لَيْلَةُ القَدْر',
      note: 'اللهم إنك عفوٌّ تحب العفو فاعفُ عنّا',
      surah: 97,
      ayah: 3,
      palette: CardPalette.night,
      frame: MushafFrame.stars,
    ),
    GreetingCard(
      id: 'eid-fitr',
      shelf: CardShelf.seasonal,
      greeting: 'عِيدُ فِطْرٍ مُبَارَك',
      note: 'تقبل الله منا ومنكم',
      surah: 2,
      ayah: 127,
      palette: CardPalette.gold,
      frame: MushafFrame.rosette,
    ),
    GreetingCard(
      id: 'eid-adha',
      shelf: CardShelf.seasonal,
      greeting: 'عِيدُ أَضْحَى مُبَارَك',
      note: 'تقبل الله منا ومنكم',
      surah: 22,
      ayah: 37,
      palette: CardPalette.emerald,
      frame: MushafFrame.chain,
    ),
    GreetingCard(
      id: 'hajj',
      shelf: CardShelf.seasonal,
      greeting: 'حَجٌّ مَبْرُور',
      note: 'وسعيٌ مشكور وذنبٌ مغفور',
      surah: 3,
      ayah: 97,
      palette: CardPalette.sand,
      frame: MushafFrame.madinah,
    ),
    GreetingCard(
      id: 'hijri-year',
      shelf: CardShelf.seasonal,
      greeting: 'عَامٌ هِجْرِيٌّ سَعِيد',
      note: 'كل عام وأنتم بخير',
      surah: 65,
      ayah: 3,
      palette: CardPalette.gold,
      frame: MushafFrame.arabesque,
    ),

    // ---- خاصة -----------------------------------------------------------
    GreetingCard(
      id: 'newborn',
      shelf: CardShelf.special,
      greeting: 'مَبْرُوكٌ المَوْلُود',
      note: 'جعله الله من الصالحين',
      surah: 25,
      ayah: 74,
      palette: CardPalette.sand,
      frame: MushafFrame.rosette,
    ),
    GreetingCard(
      id: 'recovery',
      shelf: CardShelf.special,
      greeting: 'شَفَاكَ اللهُ وَعَافَاك',
      note: 'لا بأس طهورٌ إن شاء الله',
      surah: 21,
      ayah: 83,
      palette: CardPalette.emerald,
      frame: MushafFrame.arabesque,
    ),
    GreetingCard(
      id: 'marriage',
      shelf: CardShelf.special,
      greeting: 'بَارَكَ اللهُ لَكُمَا',
      note: 'وجمع بينكما في خير',
      surah: 30,
      ayah: 21,
      palette: CardPalette.rose,
      frame: MushafFrame.filigree,
    ),
    GreetingCard(
      id: 'success',
      shelf: CardShelf.special,
      greeting: 'مَبْرُوكٌ النَّجَاح',
      note: 'زادك الله علماً وتوفيقاً',
      surah: 14,
      ayah: 7,
      palette: CardPalette.gold,
      frame: MushafFrame.stars,
    ),
    GreetingCard(
      id: 'condolence',
      shelf: CardShelf.special,
      greeting: 'عَظَّمَ اللهُ أَجْرَكُم',
      note: 'وأحسن عزاءكم وغفر لميتكم',
      surah: 2,
      ayah: 156,
      palette: CardPalette.night,
      frame: MushafFrame.keyline,
    ),
    GreetingCard(
      id: 'thanks',
      shelf: CardShelf.special,
      greeting: 'جَزَاكَ اللهُ خَيْرًا',
      surah: 55,
      ayah: 60,
      palette: CardPalette.sand,
      frame: MushafFrame.chain,
    ),
  ];

  /// The cards on [shelf] that the dashboard leaves showing, in the order it
  /// sets. Fails open like every other reader of that config: an unreachable
  /// project shows every card rather than an empty shelf.
  static List<GreetingCard> of(CardShelf shelf) {
    final shown =
        [
          for (var i = 0; i < all.length; i++)
            if (all[i].shelf == shelf &&
                SectionConfig.isVisible(all[i].sectionKey))
              (all[i], i),
        ]..sort(
          (a, b) => SectionConfig.orderOf(
            a.$1.sectionKey,
            a.$2,
          ).compareTo(SectionConfig.orderOf(b.$1.sectionKey, b.$2)),
        );
    return [for (final (card, _) in shown) card];
  }

  /// Shelves with nothing left on them drop out of the home row, so a reader
  /// never opens onto an empty grid.
  static List<CardShelf> get shelvesInUse => [
    for (final shelf in CardShelf.values)
      if (of(shelf).isNotEmpty) shelf,
  ];

  /// Fills in the verse text and its citation from the bundled Mushaf.
  static Future<ResolvedCard> resolve(GreetingCard card) async {
    final index = await QuranService.index();
    final surah = await QuranService.surah(card.surah);
    final ayah = surah.ayahs.firstWhere((a) => a.number == card.ayah);
    final name = index.firstWhere((s) => s.number == card.surah).name;

    return ResolvedCard(
      card: card,
      verse: ayah.text,
      citation: '$name: ${QuranService.toArabicDigits(card.ayah)}',
    );
  }
}
