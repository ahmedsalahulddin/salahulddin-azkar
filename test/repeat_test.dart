import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/tafsir_data.dart';
import 'package:salahulddin_azkar/services/repeat_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('repeat drill order', () {
    test('defaults to playing each ayah once', () {
      const settings = RepeatSettings();
      expect(settings.isActive, isFalse);
      expect(settings.playbackOrder(5, 100), [5]);
    });

    test('repeats a single ayah the requested number of times', () {
      const settings = RepeatSettings(perAyah: 3);
      expect(settings.isActive, isTrue);
      expect(settings.playbackOrder(7, 100), [7, 7, 7]);
    });

    test('drills each ayah before moving to the next', () {
      const settings = RepeatSettings(perAyah: 2, rangeLength: 3);
      expect(settings.playbackOrder(1, 100), [1, 1, 2, 2, 3, 3]);
    });

    test('replays the whole passage after drilling it', () {
      const settings =
          RepeatSettings(perAyah: 2, rangeLength: 2, wholeRange: 2);
      expect(settings.playbackOrder(1, 100), [1, 1, 2, 2, 1, 1, 2, 2]);
    });

    test('a range near the end of a surah stops at its last ayah', () {
      // Al-Ikhlas has 4 ayahs; asking for 10 from ayah 3 must not overrun.
      const settings = RepeatSettings(rangeLength: 10);
      expect(settings.playbackOrder(3, 4), [3, 4]);
    });

    test('total recitations are the product of the three counters', () {
      const settings =
          RepeatSettings(perAyah: 3, rangeLength: 4, wholeRange: 2);
      expect(settings.playbackOrder(1, 100).length, 3 * 4 * 2);
    });

    test('settings survive a save and reload', () async {
      const settings =
          RepeatSettings(perAyah: 5, rangeLength: 3, wholeRange: 2);
      await settings.save();

      final loaded = await RepeatSettings.load();
      expect(loaded.perAyah, 5);
      expect(loaded.rangeLength, 3);
      expect(loaded.wholeRange, 2);
      expect(loaded.isActive, isTrue);
    });
  });

  group('tafsir editions', () {
    test('the registry offers two bundled and two downloadable works', () {
      final bundled = TafsirService.editions.where((e) => e.isBundled);
      final remote = TafsirService.editions.where((e) => !e.isBundled);

      expect(bundled.length, 2);
      expect(remote.length, 2);
      // Downloadable editions must state a size before the reader commits.
      expect(remote.every((e) => e.downloadSize != null), isTrue);
      expect(remote.every((e) => e.remoteSlug != null), isTrue);
    });

    test('edition ids are unique and resolvable', () {
      final ids = TafsirService.editions.map((e) => e.id).toList();
      expect(ids.toSet().length, ids.length);
      for (final id in ids) {
        expect(TafsirService.byId(id).id, id);
      }
    });

    test('an unknown edition id falls back to the default', () {
      expect(TafsirService.byId('nonexistent').id,
          TafsirService.defaultEdition.id);
    });

    test('bundled editions cover every ayah of every surah', () async {
      for (final edition in TafsirService.editions.where((e) => e.isBundled)) {
        var total = 0;
        for (var surah = 1; surah <= 114; surah++) {
          final map = await TafsirService.forSurahIn(edition, surah);
          expect(map, isNotEmpty,
              reason: '${edition.id} has nothing for surah $surah');
          expect(map.values.any((t) => t.trim().isEmpty), isFalse,
              reason: '${edition.id} surah $surah has a blank entry');
          total += map.length;
        }
        expect(total, 6236, reason: '${edition.id} does not cover the Quran');
      }
    });

    test('the chosen edition is remembered', () async {
      await TafsirService.select('mukhtasar');
      expect((await TafsirService.selected()).id, 'mukhtasar');
    });
  });
}
