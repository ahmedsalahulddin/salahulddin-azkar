import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/adhkar_data.dart';
import '../data/greeting_cards.dart';
import '../data/hisn_data.dart';
import '../data/home_shelves.dart';
import '../data/lessons.dart';
import '../data/library_data.dart';
import '../data/quran_data.dart';
import '../l10n/strings.dart';
import 'book_reader_screen.dart';
import 'books_screen.dart';
import 'cards_screen.dart';
import 'category_screen.dart';
import 'hisn_chapter_screen.dart';
import 'lesson_screen.dart';
import 'mushaf_screen.dart';
import 'surah_screen.dart';

/// One hit: what was found, where it lives, and how to get there.
///
/// The opener takes a context rather than returning a widget, because some
/// destinations ask a question first — and because shelf items already open
/// that way, so their taps forward instead of being reinvented here.
class SearchHit {
  final String section;
  final String title;
  final String subtitle;
  final Future<void> Function(BuildContext) open;

  const SearchHit({
    required this.section,
    required this.title,
    required this.subtitle,
    required this.open,
  });
}

Future<void> _push(BuildContext context, Widget Function() build) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => build()));

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
          hits.add(
            SearchHit(
              section: shelf.title,
              title: item.title,
              subtitle: item.subtitle,
              open: item.open,
            ),
          );
        }
      }
    }

    for (final category in getCategoriesWithCount()) {
      if (hit(category.name)) {
        hits.add(
          SearchHit(
            section: t('misc.sectionAdhkar'),
            title: category.name,
            subtitle: t(
              'misc.dhikrCount',
            ).replaceAll('{count}', '${category.count}'),
            open: (c) => _push(c, () => CategoryScreen(category: category)),
          ),
        );
      }
    }

    for (final lesson in Lessons.all) {
      if (hit(lesson.title) || hit(lesson.summary)) {
        hits.add(
          SearchHit(
            section: t('misc.sectionLessons'),
            title: lesson.title,
            subtitle: lesson.summary,
            open: (c) => _push(c, () => LessonScreen(lesson: lesson)),
          ),
        );
      }
    }

    for (final book in LibraryService.books) {
      if (hit(book.title) || hit(book.author)) {
        hits.add(
          SearchHit(
            section: t('misc.sectionBooks'),
            title: book.title,
            subtitle: book.author,
            // A book on the device opens straight into the reader; one that is
            // not goes to the shelf, which knows how to fetch it.
            open: (c) => _push(
              c,
              () => book.isBundled
                  ? BookReaderScreen(book: book)
                  : const BooksScreen(),
            ),
          ),
        );
      }
    }

    for (final card in GreetingCards.all) {
      if (hit(card.greeting) || hit(card.note ?? '')) {
        hits.add(
          SearchHit(
            section: t('misc.sectionGreetingCards'),
            title: card.greeting,
            subtitle: card.shelf.title,
            open: (c) async {
              final resolved = await GreetingCards.resolve(card);
              if (c.mounted) {
                await _push(c, () => CardViewerScreen(resolved: resolved));
              }
            },
          ),
        );
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
            section: t('misc.sectionQuran'),
            title: t('misc.surahTitle').replaceAll('{name}', surah.name),
            subtitle: t('misc.ayahCountType')
                .replaceAll('{count}', '${surah.ayahCount}')
                .replaceAll('{type}', surah.type),
            open: (c) => _push(c, () => SurahScreen(info: surah)),
          ),
      for (final chapter in chapters)
        if (hit(chapter.title))
          SearchHit(
            section: t('misc.sectionHisnAlMuslim'),
            title: chapter.title,
            subtitle: t('misc.hisnChapterSubtitle'),
            open: (c) => _push(c, () => HisnChapterScreen(chapter: chapter)),
          ),
    ];
  }

  /// The words themselves, not only the names of the things holding them.
  ///
  /// A reader searching for a half-remembered phrase — a line of an ayah, the
  /// opening of a dua — was told there were no results, because the search
  /// read titles and nothing else. This pass reads the text.
  ///
  /// It runs last and separately: the ayah index is 6,236 verses read from 114
  /// files, and building it on the first keystroke would freeze the field. The
  /// titles are already on screen by the time this answers.
  static Future<List<SearchHit>> deep(String query) async {
    final trimmed = query.trim();
    // Three letters, not two: two letters of scripture match a thousand verses
    // and answer nothing. Counted before the alefs are dropped, or "الله"
    // would be two.
    if (QuranService.searchKey(trimmed).length < 3) return const [];
    final needle = QuranService.matchKey(trimmed);
    if (needle.isEmpty) return const [];
    bool hit(String text) => QuranService.matchKey(text).contains(needle);

    final hits = <SearchHit>[];

    for (final dhikr in adhkar) {
      if (!hit(dhikr.text)) continue;
      final category = categories.where((c) => c.id == dhikr.categoryId);
      if (category.isEmpty) continue;
      hits.add(
        SearchHit(
          section: t('misc.sectionAdhkarText'),
          title: _excerpt(dhikr.text),
          subtitle: category.first.name,
          open: (c) => _push(c, () => CategoryScreen(category: category.first)),
        ),
      );
    }

    for (final chapter in await HisnService.chapters()) {
      for (final item in chapter.items) {
        if (!hit(item.text)) continue;
        hits.add(
          SearchHit(
            section: t('misc.sectionHisnText'),
            title: _excerpt(item.text),
            subtitle: chapter.title,
            open: (c) => _push(c, () => HisnChapterScreen(chapter: chapter)),
          ),
        );
      }
    }

    // Capped, and the cap is said out loud rather than passed off as the whole
    // answer — "الله" alone is in more than two thousand verses.
    final ayat = await QuranService.search(trimmed);
    for (final ayah in ayat.take(_ayahCap)) {
      hits.add(
        SearchHit(
          section: t('misc.sectionQuranVerses'),
          title: _excerpt(ayah.text),
          subtitle: t('misc.ayahLocation')
              .replaceAll('{surah}', ayah.surahName)
              .replaceAll('{ayah}', QuranService.toArabicDigits(ayah.ayah)),
          open: (c) async {
            final page = await QuranService.pageOfAyah(ayah.surah, ayah.ayah);
            if (c.mounted) {
              await _push(c, () => MushafScreen(initialPage: page));
            }
          },
        ),
      );
    }
    if (ayat.length > _ayahCap) {
      hits.add(
        SearchHit(
          section: t('misc.sectionQuranVerses'),
          title: t(
            'misc.andMoreAyahs',
          ).replaceAll('{count}', QuranService.toArabicDigits(ayat.length)),
          subtitle: t('misc.openMushafSearchHint'),
          open: (c) => _push(c, () => const MushafScreen(initialPage: 1)),
        ),
      );
    }

    return hits;
  }

  static const _ayahCap = 25;

  /// Enough of the line to recognise it, cut on a word rather than mid-letter.
  static String _excerpt(String text, {int limit = 60}) {
    final clean = text.replaceAll('\n', ' ').trim();
    if (clean.length <= limit) return clean;
    final cut = clean.substring(0, limit);
    final space = cut.lastIndexOf(' ');
    return '${space > 20 ? cut.substring(0, space) : cut}…';
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

  /// The query each set of results answers. Without it a slow pass over the
  /// scripture could land after the reader has typed on, and replace the
  /// answers to the word they are looking at with answers to the one before.
  String _for = '';

  bool _reading = false;

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
    _for = query;

    // The titles answer at once; the text of the scripture takes longer and
    // arrives after, rather than holding everything back.
    final titles = AppSearch.run(query);
    if (mounted) {
      setState(() {
        _hits = titles;
        _reading = query.trim().length >= 3;
      });
    }

    final loaded = await AppSearch.loaded(query);
    if (!mounted || _for != query) return;
    setState(() => _hits = [...titles, ...loaded]);

    final deep = await AppSearch.deep(query);
    if (!mounted || _for != query) return;
    setState(() {
      _hits = [...titles, ...loaded, ...deep];
      _reading = false;
    });
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
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
            decoration: InputDecoration(
              hintText: t('misc.searchAllSectionsHint'),
              hintStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 14,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
        body: _controller.text.trim().length < 2
            ? _hint()
            : _hits.isEmpty
            ? (_reading ? _stillReading() : _nothing())
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
                          fontWeight: FontWeight.bold,
                        ),
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

  /// Shown only while nothing has matched yet: an empty screen that is about
  /// to fill is not the same as a search that found nothing.
  Widget _stillReading() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: AppColors.gold, strokeWidth: 2),
        const SizedBox(height: 14),
        Text(
          t('misc.searchingQuranAdhkar'),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    ),
  );

  Widget _hint() => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Text(
        t('misc.searchHintDetailed'),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 13,
          height: 1.9,
        ),
      ),
    ),
  );

  Widget _nothing() => Center(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Text(
        t('misc.noResultsFor').replaceAll('{query}', _controller.text.trim()),
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.textMuted, fontSize: 14),
      ),
    ),
  );

  Widget _tile(SearchHit hit) {
    return GestureDetector(
      onTap: () => hit.open(context),
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
                  Text(
                    hit.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hit.subtitle,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_left,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
