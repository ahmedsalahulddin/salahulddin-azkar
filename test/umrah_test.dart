import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/data/hisn_data.dart';
import 'package:salahulddin_azkar/data/umrah_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every stage resolves to real chapters with duas in them', () async {
    final resolved = await UmrahGuide.load();
    expect(resolved.length, UmrahGuide.stages.length);

    for (final (stage, chapters) in resolved) {
      expect(chapters, isNotEmpty,
          reason: 'stage "${stage.title}" resolved to nothing');
      expect(chapters.length, stage.chapterIds.length,
          reason: 'stage "${stage.title}" lost a chapter on the way');
      for (final c in chapters) {
        expect(c.items, isNotEmpty,
            reason: 'chapter ${c.id} in "${stage.title}" has no duas');
      }
    }
  });

  test('the stages follow the order of the rite', () async {
    final titles = UmrahGuide.stages.map((s) => s.title).toList();
    // Ihram comes before tawaf, which comes before sa'y, which comes before
    // leaving — getting this order wrong would misguide a pilgrim.
    expect(titles.indexWhere((t) => t.contains('التلبية')),
        lessThan(titles.indexWhere((t) => t.contains('الطواف'))));
    expect(titles.indexWhere((t) => t.contains('الطواف')),
        lessThan(titles.indexWhere((t) => t.contains('السعي'))));
    expect(titles.indexWhere((t) => t.contains('السعي')),
        lessThan(titles.indexWhere((t) => t.contains('العودة'))));
  });

  test('no chapter is listed under two stages', () {
    final ids = UmrahGuide.stages.expand((s) => s.chapterIds).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('Hajj-only rites are not presented as part of the Umrah', () async {
    // Arafah, Muzdalifah and stoning the pillars belong to the Hajj alone.
    const hajjOnly = {119, 120, 121};
    final used = UmrahGuide.stages.expand((s) => s.chapterIds).toSet();
    expect(used.intersection(hajjOnly), isEmpty);
  });

  test('the advertised total matches what the stages actually hold', () async {
    final resolved = await UmrahGuide.load();
    final counted = resolved.fold<int>(
      0,
      (sum, e) => sum + e.$2.fold<int>(0, (s, c) => s + c.items.length),
    );
    expect(await UmrahGuide.totalDuas(), counted);
    expect(counted, greaterThan(20));
  });

  test('every referenced chapter exists in the bundled collection', () async {
    final known = (await HisnService.chapters()).map((c) => c.id).toSet();
    for (final stage in UmrahGuide.stages) {
      for (final id in stage.chapterIds) {
        expect(known, contains(id),
            reason: 'stage "${stage.title}" points at missing chapter $id');
      }
    }
  });
}
