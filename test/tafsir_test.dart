import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/data/tafsir_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every ayah in all 114 surahs has tafsir', () async {
    var total = 0;
    for (final info in await QuranService.index()) {
      final tafsir = await TafsirService.forSurah(info.number);
      expect(tafsir.length, info.ayahCount,
          reason: 'surah ${info.number} tafsir count mismatch');

      for (var ayah = 1; ayah <= info.ayahCount; ayah++) {
        final text = tafsir[ayah];
        expect(text, isNotNull,
            reason: 'surah ${info.number} ayah $ayah has no tafsir');
        expect(text!.trim(), isNotEmpty,
            reason: 'surah ${info.number} ayah $ayah tafsir is blank');
      }
      total += tafsir.length;
    }
    expect(total, 6236);
  });

  test('tafsir is cached after the first read', () async {
    final first = await TafsirService.forSurah(112);
    final second = await TafsirService.forSurah(112);
    expect(identical(first, second), isTrue);
  });
}
