import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/adhkar_data.dart';
import '../data/greeting_cards.dart';
import '../data/library_data.dart';
import '../screens/adhkar_home_screen.dart';
import '../screens/book_reader_screen.dart';
import '../screens/books_screen.dart';
import '../screens/cards_screen.dart';
import '../screens/category_screen.dart';
import '../screens/deceased_screen.dart';
import '../screens/lessons_screen.dart';
import '../screens/memorisation_test_screen.dart';
import '../screens/mushaf_screen.dart';
import '../screens/quran_home_screen.dart';
import '../screens/quran_screen.dart';
import '../screens/sahih_adhkar_screen.dart';
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
      _adhkarShelf(),
      _quranShelf(),
      _lessonsShelf(),
      _librarySheet(),
      _cardsShelf(),
    ];

HomeShelf _adhkarShelf() {
  final categories = getCategoriesWithCount();

  return HomeShelf(
    key: 'adhkar',
    icon: '📿',
    title: 'الأذكار',
    tint: AppColors.goldMuted,
    all: () => const AdhkarHomeScreen(),
    pinned: ShelfItem(
      icon: '🕌',
      title: 'صحيح الأذكار',
      subtitle: 'حصن المسلم',
      open: (c) => _push(c, () => const SahihAdhkarScreen()),
    ),
    rest: [
      ShelfItem(
        icon: '🕋',
        title: 'أدعية العمرة',
        subtitle: 'من الميقات للتحلّل',
        open: (c) => _push(c, () => const UmrahScreen()),
      ),
      for (final category in categories)
        ShelfItem(
          icon: category.icon,
          title: category.name,
          subtitle: '${category.count} ذكر',
          open: (c) => _push(
            c,
            () => category.id == 'deceased'
                ? const DeceasedScreen()
                : CategoryScreen(category: category),
          ),
        ),
      ShelfItem(
        icon: '🔢',
        title: 'عداد التسبيح',
        subtitle: 'سبّح واحتسب',
        open: (c) => _push(c, () => const TasbihCounter(dhikr: freeTasbih)),
      ),
    ],
  );
}

HomeShelf _quranShelf() => HomeShelf(
      key: 'quran',
      icon: '📖',
      title: 'القرآن الكريم',
      tint: AppColors.emeraldMuted,
      all: () => const QuranHomeScreen(),
      pinned: ShelfItem(
        icon: '🕮',
        title: 'تلاوة وتدبّر',
        subtitle: 'آية آية مع التفسير',
        open: (c) => _push(c, () => const QuranScreen()),
      ),
      rest: [
        ShelfItem(
          icon: '📖',
          title: 'قراءة',
          subtitle: 'المصحف كاملاً',
          open: (c) async {
            final page = await StorageService.getLastMushafPage() ?? 1;
            if (!c.mounted) return;
            await _push(c, () => MushafScreen(initialPage: page));
          },
        ),
        ShelfItem(
          icon: '🧠',
          title: 'اختبار الحفظ',
          subtitle: 'أربع طرق للسؤال',
          open: openMemorisationPicker,
        ),
      ],
    );

HomeShelf _lessonsShelf() => HomeShelf(
      key: 'lessons',
      icon: '🎓',
      title: 'الدروس',
      tint: AppColors.goldMuted,
      all: () => const LessonsScreen(),
      pinned: ShelfItem(
        icon: '🧒',
        title: 'قصص الأنبياء للأطفال',
        subtitle: 'حلقات مبسّطة',
        open: (c) => _push(c, () => const LessonsScreen()),
      ),
      rest: [
        ShelfItem(
          icon: '🕌',
          title: 'قصص الأنبياء',
          subtitle: 'بالأدلة والمواضع',
          open: (c) => _push(c, () => const LessonsScreen()),
        ),
        ShelfItem(
          icon: '📜',
          title: 'التفسير',
          subtitle: 'أكثر من مفسّر',
          open: (c) => _push(c, () => const LessonsScreen()),
        ),
      ],
    );

HomeShelf _cardsShelf() {
  ShelfItem card(CardShelf shelf) => ShelfItem(
        icon: shelf.icon,
        title: shelf.title,
        subtitle: shelf.subtitle,
        open: (c) => _push(c, () => CardsScreen(shelf: shelf)),
      );

  return HomeShelf(
    key: 'cards',
    icon: '💌',
    title: 'كروت المعايدة',
    tint: AppColors.goldMuted,
    all: () => const CardsScreen(shelf: CardShelf.daily),
    pinned: card(CardShelf.daily),
    rest: [
      for (final shelf in CardShelf.values)
        if (shelf != CardShelf.daily) card(shelf),
    ],
  );
}

HomeShelf _librarySheet() {
  final books = LibraryService.books;
  final first = books.firstWhere((b) => b.isBundled, orElse: () => books.first);

  ShelfItem card(IslamicBook book) => ShelfItem(
        icon: '📕',
        title: book.title,
        subtitle: book.isBundled
            ? '${book.hadithCount} حديث'
            : 'يحتاج تنزيلاً',
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
    title: 'الكتب والأحاديث',
    tint: AppColors.emeraldMuted,
    all: () => const BooksScreen(),
    pinned: card(first),
    rest: [for (final book in books) if (book.id != first.id) card(book)],
  );
}
