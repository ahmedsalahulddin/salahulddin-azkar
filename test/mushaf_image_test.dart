import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/quran_data.dart';
import 'package:salahulddin_azkar/services/mushaf_image_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('page image URLs pad the page number to three digits', () {
    expect(MushafImageService.urlFor(1),
        'https://files.quran.app/hafs/madani/width_1024/page001.png');
    expect(MushafImageService.urlFor(77),
        'https://files.quran.app/hafs/madani/width_1024/page077.png');
    expect(MushafImageService.urlFor(304),
        'https://files.quran.app/hafs/madani/width_1024/page304.png');
    expect(MushafImageService.urlFor(QuranService.pageCount),
        'https://files.quran.app/hafs/madani/width_1024/page604.png');
  });

  test('every one of the 604 pages maps to a distinct URL', () {
    final urls = {
      for (var p = 1; p <= QuranService.pageCount; p++)
        MushafImageService.urlFor(p),
    };
    expect(urls.length, QuranService.pageCount);
  });

  test('the declared aspect ratio matches the published image dimensions', () {
    // Source images are 1024 x 1656.
    expect(MushafImageService.imageWidth, 1024);
    expect(MushafImageService.imageAspect, closeTo(1656 / 1024, 0.0001));
  });
}
