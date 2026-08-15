import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/screens/search_screen.dart';

/// The global search read titles: the names of surahs, chapters, lessons and
/// cards. A reader searching for a half-remembered phrase was told there were
/// no results, when the phrase was in the app all along.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a phrase from an ayah is found, and says where it is', () async {
    final hits = await AppSearch.deep('الحمد لله رب العالمين');
    final ayat = hits.where((h) => h.section == 'آيات القرآن');

    expect(ayat, isNotEmpty);
    expect(ayat.first.subtitle, contains('الآية'));
  });

  test('a phrase from a dhikr is found under its own section', () async {
    // The opening of Ayat al-Kursi, which the app carries in more than one
    // place; the point is that the words themselves are searchable.
    final hits = await AppSearch.deep('لا إله إلا هو الحي القيوم');
    expect(hits.map((h) => h.section).toSet(),
        anyOf(contains('نصّ الأذكار'), contains('نصّ حصن المسلم')));
  });

  test('the titles pass still answers on its own', () {
    // Two letters are enough for a title and must not wait on the scripture.
    expect(AppSearch.run('الرقية'), isNotEmpty);
  });

  test('two letters do not search the scripture', () async {
    // "من" is in a thousand verses and answers nothing; the deep pass holds
    // out for three.
    expect(await AppSearch.deep('من'), isEmpty);
  });

  test('a word in no verse and no dhikr finds nothing', () async {
    expect(await AppSearch.deep('زقزقة العصافير'), isEmpty);
  });

  test('a very common word is capped, and says that it was', () async {
    final hits = await AppSearch.deep('الله');
    final ayat = hits.where((h) => h.section == 'آيات القرآن').toList();

    expect(ayat.length, lessThanOrEqualTo(26),
        reason: 'twenty-five verses and one line saying there are more');
    expect(ayat.last.title, contains('وأكثر'));
  });

  test('every hit is trimmed to a line, never a whole page of scripture',
      () async {
    for (final hit in await AppSearch.deep('الرحمن الرحيم')) {
      expect(hit.title.length, lessThanOrEqualTo(62));
    }
  });

  group('jumping to the verse', () {
    test('an ayah resolves to the page it is printed on', () async {
      // Al-Baqarah 255 is on page 42 of the Madinah Mushaf.
      expect(await QuranService.pageOfAyah(2, 255), 42);
    });

    test('the first ayah of the Mushaf is on the first page', () async {
      expect(await QuranService.pageOfAyah(1, 1), 1);
    });

    test('an ayah that does not exist lands on its surah, not on page one',
        () async {
      // Al-Baqarah has 286; asking for 999 must not send the reader to
      // Al-Fatiha, which is what a bare fallback would do.
      expect(await QuranService.pageOfAyah(2, 999),
          await QuranService.pageOfSurah(2));
    });
  });
}
