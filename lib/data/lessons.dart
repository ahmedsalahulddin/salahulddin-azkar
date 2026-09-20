import '../l10n/strings.dart';
import 'library_data.dart';
import 'quran_data.dart';

/// Where a point in a lesson comes from.
///
/// Every claim a lesson makes is anchored to something already in the app —
/// a verse of the bundled Mushaf or a hadith of a bundled collection — and the
/// text is read from there at runtime, never copied into this file. That keeps
/// the wording exactly as the source has it, and it means a reader who wants
/// to check can open the source themselves.
sealed class LessonSource {
  const LessonSource();
}

class VerseSource extends LessonSource {
  final int surah;
  final int ayah;

  const VerseSource(this.surah, this.ayah);
}

class HadithSource extends LessonSource {
  /// Id of a bundled book in [LibraryService.books].
  final String bookId;
  final int number;

  const HadithSource(this.bookId, this.number);
}

/// One point in a lesson: a heading, the explanation, and the source behind it.
class LessonPoint {
  final String title;
  final String body;
  final LessonSource? source;

  const LessonPoint({required this.title, required this.body, this.source});
}

class Lesson {
  final String id;
  final String icon;
  final String title;
  final String summary;

  /// Read at the top of the lesson, before the points.
  final LessonSource? opening;

  final List<LessonPoint> points;

  const Lesson({
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    required this.points,
    this.opening,
  });
}

/// A source with its text filled in.
class ResolvedSource {
  final String text;
  final String citation;

  const ResolvedSource({required this.text, required this.citation});
}

class Lessons {
  /// A point's title and body, read from `lesson.<lessonId>.point.<n>.*` —
  /// built fresh on every access (like every other translated card in this
  /// app) so a locale change is picked up without restarting.
  static LessonPoint _point(String lessonId, int n, {LessonSource? source}) =>
      LessonPoint(
        title: t('lesson.$lessonId.point.$n.title'),
        body: t('lesson.$lessonId.point.$n.body'),
        source: source,
      );

  static List<Lesson> get all => [
    Lesson(
      id: 'pillars-islam',
      icon: '🕋',
      title: t('lesson.pillars-islam.title'),
      summary: t('lesson.pillars-islam.summary'),
      opening: const HadithSource('nawawi', 3),
      points: [
        _point('pillars-islam', 0),
        _point('pillars-islam', 1, source: const VerseSource(4, 103)),
        _point('pillars-islam', 2, source: const VerseSource(9, 103)),
        _point('pillars-islam', 3, source: const VerseSource(2, 183)),
        _point('pillars-islam', 4, source: const VerseSource(3, 97)),
      ],
    ),
    Lesson(
      id: 'pillars-faith',
      icon: '🌙',
      title: t('lesson.pillars-faith.title'),
      summary: t('lesson.pillars-faith.summary'),
      opening: const HadithSource('nawawi', 2),
      points: [
        _point('pillars-faith', 0, source: const VerseSource(112, 1)),
        _point('pillars-faith', 1, source: const VerseSource(66, 6)),
        _point('pillars-faith', 2, source: const VerseSource(15, 9)),
        _point('pillars-faith', 3, source: const VerseSource(2, 285)),
        _point('pillars-faith', 4, source: const VerseSource(99, 7)),
        _point('pillars-faith', 5, source: const VerseSource(54, 49)),
      ],
    ),
    Lesson(
      id: 'ihsan',
      icon: '✨',
      title: t('lesson.ihsan.title'),
      summary: t('lesson.ihsan.summary'),
      opening: const HadithSource('nawawi', 2),
      points: [
        _point('ihsan', 0),
        _point('ihsan', 1, source: const VerseSource(57, 4)),
        _point('ihsan', 2, source: const VerseSource(55, 60)),
      ],
    ),
    Lesson(
      id: 'wudu',
      icon: '💧',
      title: t('lesson.wudu.title'),
      summary: t('lesson.wudu.summary'),
      opening: const VerseSource(5, 6),
      points: [
        _point('wudu', 0, source: const HadithSource('nawawi', 1)),
        _point('wudu', 1),
        _point('wudu', 2),
        _point('wudu', 3),
        _point('wudu', 4),
      ],
    ),
    Lesson(
      id: 'salah',
      icon: '🕌',
      title: t('lesson.salah.title'),
      summary: t('lesson.salah.summary'),
      opening: const VerseSource(29, 45),
      points: [
        _point('salah', 0),
        _point('salah', 1, source: const VerseSource(2, 144)),
        _point('salah', 2),
        _point('salah', 3, source: const VerseSource(23, 2)),
      ],
    ),
    Lesson(
      id: 'niyyah',
      icon: '❤️',
      title: t('lesson.niyyah.title'),
      summary: t('lesson.niyyah.summary'),
      opening: const HadithSource('nawawi', 1),
      points: [
        _point('niyyah', 0),
        _point('niyyah', 1),
        _point('niyyah', 2, source: const VerseSource(98, 5)),
      ],
    ),
  ];

  static Lesson byId(String id) => all.firstWhere((l) => l.id == id);

  /// Reads a source's text out of the bundle it belongs to.
  ///
  /// Returns null when the text cannot be read — a lesson still stands without
  /// its citation showing, and a missing source is no reason to fail a screen.
  static Future<ResolvedSource?> resolve(LessonSource source) async {
    try {
      switch (source) {
        case VerseSource(:final surah, :final ayah):
          final index = await QuranService.index();
          final loaded = await QuranService.surah(surah);
          final verse = loaded.ayahs.firstWhere((a) => a.number == ayah);
          final name = index.firstWhere((s) => s.number == surah).name;
          return ResolvedSource(
            text: verse.text,
            citation: '$name: ${QuranService.toArabicDigits(ayah)}',
          );

        case HadithSource(:final bookId, :final number):
          final book = LibraryService.books.firstWhere((b) => b.id == bookId);
          final hadiths = await LibraryService.hadiths(book);
          final hadith = hadiths.firstWhere((h) => h.number == number);
          return ResolvedSource(
            text: hadith.text,
            citation:
                '${book.title} — حديث ${QuranService.toArabicDigits(number)}',
          );
      }
    } catch (_) {
      return null;
    }
  }
}
