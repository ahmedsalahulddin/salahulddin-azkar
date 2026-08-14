import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';

/// Search has to work for someone typing plainly on a phone keyboard: no
/// tashkeel, no alef wasla, no hamza niceties.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('search key', () {
    test('strips the marks a reader will never type', () async {
      final fatiha = await QuranService.surah(1);
      final marked = fatiha.ayahs[1].text; // carries full tashkeel
      final key = QuranService.searchKey(marked);

      expect(key.length, lessThan(marked.length),
          reason: 'diacritics should have been removed');
      // Nothing from the harakat range survives.
      expect(
        key.runes.any((r) => r >= 0x064B && r <= 0x065F),
        isFalse,
      );
    });

    test('folds letter variants a reader will not distinguish', () {
      expect(QuranService.searchKey('ٱلرَّحۡمَٰن'),
          QuranService.searchKey('الرحمن'));
      expect(QuranService.searchKey('إِيمَان'), QuranService.searchKey('ايمان'));
      expect(QuranService.searchKey('صَلَاةِ'), QuranService.searchKey('صلاه'));
    });
  });

  group('searching the Mushaf', () {
    test('a plainly typed word finds marked-up verses', () async {
      final hits = await QuranService.search('الرحمن');
      expect(hits, isNotEmpty);
      // Every hit really does contain it once folded.
      final needle = QuranService.searchKey('الرحمن');
      expect(hits.every((h) => QuranService.searchKey(h.text).contains(needle)),
          isTrue);
    });

    test('results come back in Mushaf order', () async {
      final hits = await QuranService.search('الحمد');
      for (var i = 1; i < hits.length; i++) {
        final before = hits[i - 1];
        final now = hits[i];
        final ordered = now.surah > before.surah ||
            (now.surah == before.surah && now.ayah > before.ayah);
        expect(ordered, isTrue,
            reason: 'hit ${now.surah}:${now.ayah} came after '
                '${before.surah}:${before.ayah}');
      }
    });

    test('occurrences count repeats within one verse', () async {
      // Never fewer occurrences than verses containing the word.
      final hits = await QuranService.search('الله');
      final total = await QuranService.countOccurrences('الله');
      expect(total, greaterThanOrEqualTo(hits.length));
    });

    test('an empty or whitespace query returns nothing rather than everything',
        () async {
      expect(await QuranService.search(''), isEmpty);
      expect(await QuranService.search('   '), isEmpty);
      expect(await QuranService.countOccurrences(''), 0);
    });

    test('a word that is not in the Mushaf returns no hits', () async {
      expect(await QuranService.search('زقزقة'), isEmpty);
    });

    test('every hit points at a real ayah', () async {
      final index = await QuranService.index();
      final counts = {for (final s in index) s.number: s.ayahCount};

      for (final hit in await QuranService.search('يوم')) {
        expect(counts.containsKey(hit.surah), isTrue);
        expect(hit.ayah, inInclusiveRange(1, counts[hit.surah]!));
        expect(hit.text.trim(), isNotEmpty);
      }
    });
  });
}
