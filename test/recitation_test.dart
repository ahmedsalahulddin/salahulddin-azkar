import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/recitation_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('audio URLs zero-pad surah and ayah to three digits', () {
    expect(
      RecitationService.urlFor(reciterId: 'Husary_128kbps', surah: 1, ayah: 1),
      'https://everyayah.com/data/Husary_128kbps/001001.mp3',
    );
    expect(
      RecitationService.urlFor(reciterId: 'Husary_128kbps', surah: 2, ayah: 255),
      'https://everyayah.com/data/Husary_128kbps/002255.mp3',
    );
    // Largest addressable ayah: surah 114, ayah 6.
    expect(
      RecitationService.urlFor(reciterId: 'Alafasy_128kbps', surah: 114, ayah: 6),
      'https://everyayah.com/data/Alafasy_128kbps/114006.mp3',
    );
  });

  test('reciter ids are unique and non-empty', () {
    final ids = RecitationService.reciters.map((r) => r.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(ids.any((id) => id.isEmpty), isFalse);
  });

  test('an unknown stored reciter falls back to the default', () async {
    SharedPreferences.setMockInitialValues({'@noor_reciter': 'Deleted_Reciter'});
    expect((await RecitationService.getReciter()).id,
        RecitationService.defaultReciter.id);
  });

  test('a stored reciter is remembered', () async {
    await RecitationService.setReciter('Alafasy_128kbps');
    expect((await RecitationService.getReciter()).id, 'Alafasy_128kbps');
  });
}
