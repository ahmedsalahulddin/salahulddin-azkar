import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/adhkar_data.dart';
import 'package:salahulddin_azkar/data/library_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('library catalogue', () {
    test('book ids are unique and every entry is described', () {
      final ids = LibraryService.books.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length);

      for (final b in LibraryService.books) {
        expect(b.title.trim(), isNotEmpty);
        expect(b.author.trim(), isNotEmpty, reason: '${b.id} has no author');
        expect(b.hadithCount, greaterThan(0));
      }
    });

    test('downloadable books state their size, bundled ones do not', () {
      for (final b in LibraryService.books) {
        if (b.isBundled) {
          expect(b.downloadSize, isNull, reason: '${b.id} is bundled');
        } else {
          expect(b.remoteSlug, isNotNull);
          expect(b.downloadSize, isNotNull,
              reason: '${b.id} must state its size before the reader commits');
        }
      }
    });

    test('an unknown id falls back to the first book', () {
      expect(LibraryService.byId('nonexistent').id,
          LibraryService.books.first.id);
    });
  });

  group('bundled books', () {
    test('each opens with the number of hadiths it advertises', () async {
      final bundled = LibraryService.books.where((b) => b.isBundled).toList();
      expect(bundled.length, 3);

      for (final book in bundled) {
        final hadiths = await LibraryService.hadiths(book);
        expect(hadiths.length, book.hadithCount,
            reason: '${book.id} count disagrees with the catalogue');
        expect(hadiths.any((h) => h.text.trim().isEmpty), isFalse,
            reason: '${book.id} has an empty hadith');
        expect(await LibraryService.isDownloaded(book), isTrue);
      }
    });

    test('hadith numbering is unique within a book', () async {
      for (final book in LibraryService.books.where((b) => b.isBundled)) {
        final numbers =
            (await LibraryService.hadiths(book)).map((h) => h.number).toList();
        expect(numbers.toSet().length, numbers.length,
            reason: '${book.id} repeats a hadith number');
      }
    });

    test('books are cached after the first read', () async {
      final first = await LibraryService.hadiths(LibraryService.books.first);
      final second = await LibraryService.hadiths(LibraryService.books.first);
      expect(identical(first, second), isTrue);
    });
  });

  group('adhkar recitation links', () {
    test('only exactly-matched adhkar carry audio, over HTTPS', () {
      final withAudio = adhkar.where((d) => d.hasAudio).toList();

      // Loose matching was rejected: it linked the tahlil to the morning
      // supplication and Al-Falaq to Al-Ikhlas. Only exact matches remain.
      expect(withAudio.length, 9);
      for (final d in withAudio) {
        expect(d.audioUrl, startsWith('https://'));
        expect(d.audioId, greaterThan(0));
      }
    });

    test('adhkar without a verified recitation expose none', () {
      for (final d in adhkar.where((d) => !d.hasAudio)) {
        expect(d.audioUrl, isNull);
      }
    });
  });
}
