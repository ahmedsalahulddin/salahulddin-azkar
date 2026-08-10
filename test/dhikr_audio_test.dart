import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/hisn_data.dart';
import 'package:salahulddin_azkar/data/umrah_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('recitation URLs are built from the published id over HTTPS', () {
    const dhikr = HisnDhikr(number: 1, text: 'x', repeat: 1, audioId: 27);
    expect(dhikr.hasAudio, isTrue);
    expect(dhikr.audioUrl, 'https://www.hisnmuslim.com/audio/ar/27.mp3');
    // Plain HTTP would be blocked by Android's cleartext policy.
    expect(dhikr.audioUrl, startsWith('https://'));
  });

  test('a dhikr without a published recitation reports none', () {
    const dhikr = HisnDhikr(number: 1, text: 'x', repeat: 1);
    expect(dhikr.hasAudio, isFalse);
    expect(dhikr.audioUrl, isNull);
  });

  test('all but one of the 267 adhkar carry a recitation', () async {
    final all =
        (await HisnService.chapters()).expand((c) => c.items).toList();
    expect(all.length, 267);

    final withAudio = all.where((d) => d.hasAudio).toList();
    // The source ships one malformed audio link; it must degrade to no button
    // rather than a broken one.
    expect(withAudio.length, 266);
    expect(withAudio.every((d) => d.audioId! > 0), isTrue);
  });

  test('recitation ids are unique across the whole collection', () async {
    final ids = (await HisnService.chapters())
        .expand((c) => c.items)
        .where((d) => d.hasAudio)
        .map((d) => d.audioId!)
        .toList();
    expect(ids.toSet().length, ids.length);
  });

  test('every Umrah dua can be listened to', () async {
    for (final (stage, chapters) in await UmrahGuide.load()) {
      for (final chapter in chapters) {
        for (final dhikr in chapter.items) {
          expect(dhikr.hasAudio, isTrue,
              reason:
                  'stage "${stage.title}" chapter ${chapter.id} dhikr ${dhikr.number} has no recitation');
        }
      }
    }
  });
}
