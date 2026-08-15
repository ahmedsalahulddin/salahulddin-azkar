import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/section_config.dart';
import 'package:salahulddin_azkar/widgets/mushaf_frames.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The dashboard can hide and reorder the borders. Two things must hold: a
/// reader is never left with an ornament nobody else can see, and the picker
/// is never empty — a page has to have some border, even "none".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SectionConfig.settings.value = {};
    SectionConfig.debugSetLoaded(false);
  });

  void configure(Map<String, (bool enabled, int order)> rows) {
    SectionConfig.settings.value = {
      for (final entry in rows.entries)
        entry.key: SectionSetting(
          key: entry.key,
          title: entry.key,
          enabled: entry.value.$1,
          sortOrder: entry.value.$2,
        ),
    };
    SectionConfig.debugSetLoaded(true);
  }

  test('the keys match what the SQL inserts', () {
    final sql = File('supabase/frame_sections.sql').readAsStringSync();
    for (final frame in MushafFrame.values) {
      expect(frame.sectionKey, 'frame_${frame.id}');
      expect(sql, contains("('${frame.sectionKey}'"),
          reason: '${frame.label} has no row to switch it off');
    }
  });

  test('unconfigured means available — the config fails open', () {
    expect(MushafFrame.available, MushafFrame.values);
  });

  test('a hidden frame leaves the picker', () {
    configure({
      for (final f in MushafFrame.values)
        f.sectionKey: (f != MushafFrame.illuminated, f.index),
    });
    expect(MushafFrame.available, isNot(contains(MushafFrame.illuminated)));
    expect(MushafFrame.available.length, MushafFrame.values.length - 1);
  });

  test('the dashboard order is the picker order', () {
    configure({
      MushafFrame.keyline.sectionKey: (true, 3),
      MushafFrame.stars.sectionKey: (true, 1),
      MushafFrame.none.sectionKey: (true, 2),
      for (final f in MushafFrame.values)
        if (f != MushafFrame.keyline &&
            f != MushafFrame.stars &&
            f != MushafFrame.none)
          f.sectionKey: (false, 9),
    });
    expect(MushafFrame.available,
        [MushafFrame.stars, MushafFrame.none, MushafFrame.keyline]);
  });

  test('hiding every frame still leaves something to draw', () {
    configure({
      for (final f in MushafFrame.values) f.sectionKey: (false, f.index),
    });
    expect(MushafFrame.available, isNotEmpty,
        reason: 'the picker must never be empty');
  });

  test('a reader on a frame that gets hidden is moved off it', () async {
    await MushafFrames.choose(MushafFrame.illuminated);
    expect(MushafFrames.current.value, MushafFrame.illuminated);

    configure({
      for (final f in MushafFrame.values)
        f.sectionKey: (f != MushafFrame.illuminated, f.index),
    });
    MushafFrames.reconcile();

    expect(MushafFrames.current.value, isNot(MushafFrame.illuminated));
    expect(MushafFrame.available, contains(MushafFrames.current.value));
  });

  test('a reader on a frame that stays is left alone', () async {
    await MushafFrames.choose(MushafFrame.stars);
    configure({
      for (final f in MushafFrame.values)
        f.sectionKey: (f != MushafFrame.illuminated, f.index),
    });
    MushafFrames.reconcile();
    expect(MushafFrames.current.value, MushafFrame.stars,
        reason: 'hiding one frame must not disturb readers on another');
  });
}
