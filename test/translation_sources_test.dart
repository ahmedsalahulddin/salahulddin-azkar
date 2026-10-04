import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/screens/quran_translation_screen.dart';

void main() {
  test('QuranEnc text arrives without its footnote markers', () {
    const body =
        '{"result":[{"id":"1","sura":"1","aya":"1","translation":"(Empiezo)[2] con el nombre de Al-lah[3], el Clemente, el Misericordioso[4].","footnotes":"[2] A pesar de que..."},'
        '{"id":"2","sura":"1","aya":"2","translation":"¡Alabado sea Al-lah, Señor de toda la creación!,","footnotes":""}]}';
    expect(parseTranslationBody(body), [
      '(Empiezo) con el nombre de Al-lah, el Clemente, el Misericordioso.',
      '¡Alabado sea Al-lah, Señor de toda la creación!,',
    ]);
  });

  test('fawazahmed0 Bengali text arrives without footnote markers', () {
    const body =
        '{"chapter":[{"chapter":1,"verse":1,"text":"রহমান, রহীম [১] আল্লাহ্‌র নামে [২]"}]}';
    expect(parseTranslationBody(body), ['রহমান, রহীম আল্লাহ্‌র নামে']);
  });

  test('alquran.cloud surahs read as before', () {
    const body =
        '{"code":200,"data":{"ayahs":[{"text":"In the name of Allah"},{"text":"All praise is due to Allah"}]}}';
    expect(parseTranslationBody(body), [
      'In the name of Allah',
      'All praise is due to Allah',
    ]);
  });
}
