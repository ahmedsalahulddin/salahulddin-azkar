import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';

/// Readers type surah names plainly — no hamza, no madda, no ta marbuta, and
/// usually without the article. Comparing the raw stored names finds none of
/// those, which is what made the search look broken.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<SurahInfo> index;
  setUpAll(() async => index = await QuranService.index());

  SurahInfo of(int n) => index.firstWhere((s) => s.number == n);

  List<int> search(String q) =>
      index.where((s) => QuranService.surahMatches(s, q)).map((s) => s.number).toList();

  test('a plainly typed name finds the surah that spells it properly', () {
    // الإخلاص carries a hamza the reader will not type.
    expect(search('اخلاص'), contains(112));
    // آل عمران opens with a madda.
    expect(search('ال عمران'), contains(3));
    // النبأ ends in one.
    expect(search('النبا'), contains(78));
    // الفاتحة ends in ta marbuta.
    expect(search('الفاتحه'), contains(1));
  });

  test('the article can be left off', () {
    expect(search('بقره'), contains(2));
    expect(search('عمران'), contains(3));
    expect(search('كوثر'), contains(108));
  });

  test('the number works in either set of digits', () {
    expect(search('36'), [36]);
    expect(search('٣٦'), [36]);
    expect(search('١'), [1]);
  });

  test('the English name still works', () {
    expect(search(of(112).nameEn), contains(112));
    expect(search(of(112).nameEn.toUpperCase()), contains(112));
  });

  test('an empty query keeps every surah', () {
    expect(search('').length, 114);
    expect(search('   ').length, 114);
  });

  test('a word in no surah name finds nothing', () {
    expect(search('زقزقة'), isEmpty);
  });

  test('every surah can be found by its own name as printed', () {
    for (final s in index) {
      expect(QuranService.surahMatches(s, s.name), isTrue,
          reason: '${s.name} cannot find itself');
    }
  });

  test('letters that are not digits are not read as a number', () {
    // "٣ب" is not surah 3.
    expect(QuranService.toWesternDigits('٣ب'), '');
    expect(QuranService.toWesternDigits('٣٦'), '36');
  });
}
