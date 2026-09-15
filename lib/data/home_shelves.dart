import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../data/adhkar_data.dart';
import '../data/greeting_cards.dart';
import '../data/lessons.dart';
import '../data/library_data.dart';
import '../data/stories_data.dart';
import '../screens/adhkar_home_screen.dart';
import '../screens/book_reader_screen.dart';
import '../screens/books_screen.dart';
import '../screens/cards_screen.dart';
import '../screens/category_screen.dart';
import '../screens/deceased_screen.dart';
import '../screens/lesson_screen.dart';
import '../screens/lessons_screen.dart';
import '../screens/memorisation_test_screen.dart';
import '../screens/mushaf_screen.dart';
import '../screens/my_cards_screen.dart';
import '../screens/quran_home_screen.dart';
import '../screens/quran_translation_screen.dart';
import '../screens/listening_screen.dart';
import '../screens/radio_screen.dart';
import '../screens/quran_screen.dart';
import '../screens/sahih_adhkar_screen.dart';
import '../screens/stories_home_screen.dart';
import '../screens/story_category_screen.dart';
import '../screens/umrah_screen.dart';
import '../services/storage_service.dart';
import '../widgets/tasbih_counter.dart';

/// Free-running tasbih, not tied to any one dhikr.
const freeTasbih = Dhikr(
  id: 'free-tasbih',
  categoryId: 'tasbih',
  text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
  source: 'صحيح مسلم',
  repetitions: 33,
);

/// One card on a shelf.
class ShelfItem {
  final String icon;
  final String title;
  final String subtitle;

  /// Opens the item. Takes the context because some items ask a question
  /// first — picking a surah, for one — rather than pushing a fixed screen.
  final Future<void> Function(BuildContext) open;

  const ShelfItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.open,
  });
}

/// A row on the home screen: a title, a card that stays put, and the rest
/// running off to the side.
class HomeShelf {
  /// Matches the key in app_sections, so a shelf can be hidden remotely.
  final String key;
  final String icon;
  final String title;
  final Color tint;

  /// The first card, which does not scroll — the one thing on this shelf a
  /// reader reaches for most.
  final ShelfItem pinned;

  final List<ShelfItem> rest;

  /// Opens the shelf's own screen, behind "الكل".
  final Widget Function() all;

  const HomeShelf({
    required this.key,
    required this.icon,
    required this.title,
    required this.tint,
    required this.pinned,
    required this.rest,
    required this.all,
  });
}

Future<void> _push(BuildContext context, Widget Function() build) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => build()));

/// The shelves, built fresh so the adhkar counts and book list are
/// whatever they are now rather than whatever they were at startup.
List<HomeShelf> buildShelves() => [
      _quranShelf(),
      _adhkarShelf(),
      _storiesShelf(),
      _lessonsShelf(),
      _librarySheet(),
      _cardsShelf(),
    ];

HomeShelf _storiesShelf() {
  final categories = getStoryCategoriesWithCount();

  return HomeShelf(
    key: 'stories',
    icon: '📜',
    title: tBoth('shelf.stories.title'),
    tint: AppColors.emeraldMuted,
    all: () => const StoriesHomeScreen(),
    pinned: ShelfItem(
      icon: categories.first.icon,
      title: tBoth('story.cat.${categories.first.id}'),
      subtitle: '${categories.first.count} ${t('story.countSuffix')}',
      open: (c) => _push(
        c,
        () => StoryCategoryScreen(category: categories.first),
      ),
    ),
    rest: [
      for (final category in categories.skip(1))
        ShelfItem(
          icon: category.icon,
          title: tBoth('story.cat.${category.id}'),
          subtitle: '${category.count} ${t('story.countSuffix')}',
          open: (c) => _push(
            c,
            () => StoryCategoryScreen(category: category),
          ),
        ),
    ],
  );
}

HomeShelf _adhkarShelf() {
  final categories = getCategoriesWithCount();

  return HomeShelf(
    key: 'adhkar',
    icon: '📿',
    title: tBoth('shelf.adhkar.title'),
    tint: AppColors.goldMuted,
    all: () => const AdhkarHomeScreen(),
    pinned: ShelfItem(
      icon: '🕌',
      title: tBoth('card.sahih.title'),
      subtitle: tBoth('card.sahih.sub'),
      open: (c) => _push(c, () => const SahihAdhkarScreen()),
    ),
    rest: [
      ShelfItem(
        icon: '🕋',
        title: tBoth('card.umrah.title'),
        subtitle: tBoth('card.umrah.sub'),
        open: (c) => _push(c, () => const UmrahScreen()),
      ),
      for (final category in categories)
        ShelfItem(
          icon: category.icon,
          title: tBoth('adhkar.cat.${category.id}'),
          subtitle: '${category.count} ${t('adhkar.countSuffix')}',
          open: (c) => _push(
            c,
            () => category.id == 'deceased'
                ? const DeceasedScreen()
                : CategoryScreen(category: category),
          ),
        ),
      ShelfItem(
        icon: '🔢',
        title: tBoth('card.tasbih.title'),
        subtitle: tBoth('card.tasbih.sub'),
        open: (c) => _push(c, () => const TasbihCounter(dhikr: freeTasbih)),
      ),
    ],
  );
}

HomeShelf _quranShelf() => HomeShelf(
      key: 'quran',
      icon: '📖',
      title: tBoth('shelf.quran.title'),
      tint: AppColors.emeraldMuted,
      all: () => const QuranHomeScreen(),
      pinned: ShelfItem(
        icon: '📖',
        title: tBoth('card.mushaf.title'),
        subtitle: tBoth('card.mushaf.sub'),
        open: (c) async {
          final page = await StorageService.getLastMushafPage() ?? 1;
          if (!c.mounted) return;
          await _push(c, () => MushafScreen(initialPage: page));
        },
      ),
      rest: [
        ShelfItem(
          icon: '🌍',
          title: tBoth('card.translation.title'),
          subtitle: tBoth('card.translation.sub'),
          open: (c) => _push(c, () => const QuranTranslationScreen()),
        ),
        ShelfItem(
          icon: '🕌',
          title: tBoth('card.recitation.title'),
          subtitle: tBoth('card.recitation.sub'),
          open: (c) => _push(c, () => const QuranScreen()),
        ),
        ShelfItem(
          icon: '🧠',
          title: tBoth('card.memtest.title'),
          subtitle: tBoth('card.memtest.sub'),
          open: openMemorisationPicker,
        ),
        ShelfItem(
          icon: '📻',
          title: tBoth('card.radio.title'),
          subtitle: tBoth('card.radio.sub'),
          open: (c) => _push(c, () => const RadioScreen()),
        ),
        ShelfItem(
          icon: '🎧',
          title: tBoth('card.listen.title'),
          subtitle: tBoth('card.listen.sub'),
          open: (c) => _push(c, () => const ListeningScreen()),
        ),
      ],
    );

HomeShelf _lessonsShelf() => HomeShelf(
      key: 'lessons',
      icon: '🎓',
      title: tBoth('shelf.lessons.title'),
      tint: AppColors.goldMuted,
      all: () => const LessonsScreen(),
      pinned: ShelfItem(
        icon: Lessons.all.first.icon,
        title: tBoth('lesson.${Lessons.all.first.id}.title'),
        subtitle: tBoth('lesson.${Lessons.all.first.id}.summary'),
        open: (c) => _push(c, () => LessonScreen(lesson: Lessons.all.first)),
      ),
      rest: [
        for (final lesson in Lessons.all.skip(1))
          ShelfItem(
            icon: lesson.icon,
            title: tBoth('lesson.${lesson.id}.title'),
            subtitle: tBoth('lesson.${lesson.id}.summary'),
            open: (c) => _push(c, () => LessonScreen(lesson: lesson)),
          ),
        ShelfItem(
          icon: '🎬',
          title: tBoth('card.prophets.title'),
          subtitle: tBoth('card.prophets.sub'),
          open: (c) => _push(c, () => const LessonsScreen()),
        ),
      ],
    );

HomeShelf _cardsShelf() {
  ShelfItem card(CardShelf shelf) => ShelfItem(
        icon: shelf.icon,
        title: tBoth('cardshelf.${shelf.id}.title'),
        subtitle: tBoth('cardshelf.${shelf.id}.subtitle'),
        open: (c) => _push(c, () => CardsScreen(shelf: shelf)),
      );

  return HomeShelf(
    key: 'cards',
    icon: '💌',
    title: tBoth('shelf.cards.title'),
    tint: AppColors.goldMuted,
    all: () => const MyCardsScreen(),
    // The reader's own cards lead; the ready-made shelves follow.
    pinned: ShelfItem(
      icon: '🖼️',
      title: tBoth('card.mycards.title'),
      subtitle: tBoth('card.mycards.sub'),
      open: (c) => _push(c, () => const MyCardsScreen()),
    ),
    rest: [for (final shelf in GreetingCards.shelvesInUse) card(shelf)],
  );
}

HomeShelf _librarySheet() {
  final books = LibraryService.books;
  final first = books.firstWhere((b) => b.isBundled, orElse: () => books.first);

  ShelfItem card(IslamicBook book) => ShelfItem(
        icon: '📕',
        title: tBoth('book.${book.id}'),
        subtitle: book.isBundled
            ? '${book.hadithCount} ${t('card.hadithCount')}'
            : t('card.needsDownload'),
        // A book already on the device opens straight into the reader; one
        // that is not goes to the shelf screen, which knows how to fetch it.
        open: (c) => _push(
          c,
          () => book.isBundled
              ? BookReaderScreen(book: book)
              : const BooksScreen(),
        ),
      );

  return HomeShelf(
    key: 'library',
    icon: '📚',
    title: tBoth('shelf.library.title'),
    tint: AppColors.emeraldMuted,
    all: () => const BooksScreen(),
    pinned: card(first),
    rest: [for (final book in books) if (book.id != first.id) card(book)],
  );
}
