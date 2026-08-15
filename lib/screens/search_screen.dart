import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/adhkar_data.dart';
import '../data/greeting_cards.dart';
import '../data/hisn_data.dart';
import '../data/home_shelves.dart';
import '../data/lessons.dart';
import '../data/library_data.dart';
import '../data/quran_data.dart';
import 'category_screen.dart';
import 'lesson_screen.dart';
import 'quran_screen.dart';

/// One hit: what was found, where it lives, and how to get there.
class SearchHit {
  final String section;
  final String title;
  final String subtitle;
  final Widget Function() open;

  const SearchHit({
    required this.section,
    required this.title,
    required this.subtitle,
    required this.open,
  });
}

/// Searches every corner of the app at once.
///
/// Arabic is matched through the same folding the Mushaf search uses — a
/// reader types "اذكار" and must find "أذكار", types half a word and must
/// still find it. Anything less is a search that works only for people who
/// already know the spelling.
class AppSearch {
  static List<SearchHit> run(String query) {
    final needle = QuranService.searchKey(query.trim());
    if (needle.length < 2) return const [];

    bool hit(String text) => QuranService.searchKey(text).contains(needle);

    final hits = <SearchHit>[];

    // Shelves and their cards — the app's own furniture.
    for (final shelf in buildShelves()) {
      for (final item in [shelf.pinned, ...shelf.rest]) {
        if (hit(item.title) || hit(item.subtitle) || hit(shelf.title)) {
          hits.add(SearchHit(
            section: shelf.title,
            title: item.title,
            subtitle: item.subtitle,
            // Shelf items open through a context, so the tap is forwarded
            // rather than wrapped in a widget here.
            open: () => const SizedBox.shrink(),
          ));
        }
      }
    }

    for (final category in getCategoriesWithCount()) {
      if (hit(category.name)) {
        hits.add(SearchHit(
          section: 'الأذكار',
          title: category.name,
          subtitle: '${category.count} ذكر',
          open: () => CategoryScreen(category: category),
        ));
      }
    }

    for (final lesson in Lessons.all) {
      if (hit(lesson.title) || hit(lesson.summary)) {
        hits.add(SearchHit(
          section: 'الدروس',
          title: lesson.title,
          subtitle: lesson.summary,
          open: () => LessonScreen(lesson: lesson),
        ));
      }
    }

    for (final book in LibraryService.books) {
      if (hit(book.title) || hit(book.author)) {
        hits.add(SearchHit(
          section: 'الكتب والأحاديث',
          title: book.title,
          subtitle: book.author,
          open: () => const QuranScreen(),
        ));
      }
    }

    for (final card in GreetingCards.all) {
      if (hit(card.greeting) || hit(card.note ?? '')) {
        hits.add(SearchHit(
          section: 'كروت المعايدة',
          title: card.greeting,
          subtitle: card.shelf.title,
          open: () => const QuranScreen(),
        ));
      }
    }

    return hits;
  }

  /// What has to be loaded before it can be searched: the surah index and the
  /// chapters of Hisn al-Muslim.
  static Future<List<SearchHit>> loaded(String query) async {
    final needle = QuranService.searchKey(query.trim());
    if (needle.length < 2) return const [];
    bool hit(String text) => QuranService.searchKey(text).contains(needle);

    final index = await QuranService.index();
    final chapters = await HisnService.chapters();

    return [
      for (final surah in index)
        if (QuranService.surahMatches(surah, query))
          SearchHit(
            section: 'القرآن الكريم',
            title: 'سورة ${surah.name}',
            subtitle: '${surah.ayahCount} آية — ${surah.type}',
            open: () => const QuranScreen(),
          ),
      for (final chapter in chapters)
        if (hit(chapter.title))
          SearchHit(
            section: 'حصن المسلم',
            title: chapter.title,
            subtitle: 'باب من صحيح الأذكار',
            open: () => const QuranScreen(),
          ),
    ];
  }
}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<SearchHit> _hits = const [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_search);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text;
    final hits = AppSearch.run(query);
    final loaded = await AppSearch.loaded(query);
    if (mounted) setState(() => _hits = [...hits, ...loaded]);
  }

  @override
  Widget build(BuildContext context) {
    // Grouped by section, because "where is this" is half the question.
    final grouped = <String, List<SearchHit>>{};
    for (final hit in _hits) {
      grouped.putIfAbsent(hit.section, () => []).add(hit);
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.right,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 15),
            decoration: const InputDecoration(
              hintText: 'ابحث في كل الأقسام…',
              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
              border: InputBorder.none,
            ),
          ),
        ),
        body: _controller.text.trim().length < 2
            ? _hint()
            : _hits.isEmpty
                ? _nothing()
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      for (final entry in grouped.entries) ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(2, 8, 2, 8),
                          child: Text(
                            '${entry.key} · ${QuranService.toArabicDigits(entry.value.length)}',
                            style: const TextStyle(
                                color: AppColors.gold,
                                fontSize: 13,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        for (final hit in entry.value) _tile(hit),
                      ],
                      const SizedBox(height: 20),
                    ],
                  ),
      ),
    );
  }

  Widget _hint() => const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Text(
            'اكتب حرفين على الأقل.\nالبحث يشمل الأذكار والسور والدروس والكتب والكروت.',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: AppColors.textMuted, fontSize: 13, height: 1.9),
          ),
        ),
      );

  Widget _nothing() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Text(
            'لا نتائج لـ «${_controller.text.trim()}»',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),
        ),
      );

  Widget _tile(SearchHit hit) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => hit.open()),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hit.title,
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(hit.subtitle,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left,
                color: AppColors.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}
