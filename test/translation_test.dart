import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/translation_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('the catalogue covers six languages with unique ids and slugs', () {
    final ids = TranslationService.available.map((t) => t.id).toList();
    final slugs = TranslationService.available.map((t) => t.slug).toList();

    expect(TranslationService.available.length, 6);
    expect(ids.toSet().length, ids.length);
    expect(slugs.toSet().length, slugs.length);
    expect(slugs.any((s) => s.trim().isEmpty), isFalse);
  });

  test('every entry names its language and translator', () {
    for (final t in TranslationService.available) {
      expect(t.language.trim(), isNotEmpty, reason: '${t.id} has no language');
      expect(t.translator.trim(), isNotEmpty,
          reason: '${t.id} has no translator credit');
    }
  });

  test('right-to-left is flagged only where it applies', () {
    // Urdu is the one RTL translation in the catalogue.
    expect(TranslationService.byId('ur').isRtl, isTrue);
    expect(TranslationService.byId('en').isRtl, isFalse);
    expect(TranslationService.byId('id').isRtl, isFalse);
  });

  test('an unknown id falls back to the first translation', () {
    expect(TranslationService.byId('zz').id,
        TranslationService.available.first.id);
  });

  test('no translation is selected until the reader picks one', () async {
    expect(await TranslationService.selected(), isNull);

    await TranslationService.select('ur');
    expect((await TranslationService.selected())?.id, 'ur');
  });

  test('a selection that no longer exists resolves to nothing', () async {
    SharedPreferences.setMockInitialValues({'@noor_translation': 'removed'});
    expect(await TranslationService.selected(), isNull);
  });
}
