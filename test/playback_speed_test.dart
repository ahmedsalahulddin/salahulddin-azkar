import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/services/playback_speed.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The speed used to live inside the Mushaf screen, so it applied to the
/// recitation of the pages and to nothing else. One setting now serves every
/// player — except a broadcast, which has no timeline to compress.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PlaybackSpeed.value.value = 1.0;
    await PlaybackSpeed.load();
  });

  test('starts at the normal speed', () {
    expect(PlaybackSpeed.value.value, 1.0);
  });

  test('a chosen speed survives the next run', () async {
    await PlaybackSpeed.set(1.5);
    PlaybackSpeed.value.value = 1.0;

    await PlaybackSpeed.load();
    expect(PlaybackSpeed.value.value, 1.5);
  });

  test('a stored value that is not on the dial reads as normal', () async {
    // A hand-edited store, or a build that offered other steps. The picker can
    // only show what it lists, and a speed it cannot show cannot be undone.
    SharedPreferences.setMockInitialValues({'@noor_playback_speed': 3.7});
    await PlaybackSpeed.load();
    expect(PlaybackSpeed.value.value, 1.0);
  });

  test('the dial runs from half speed to double, through normal', () {
    expect(PlaybackSpeed.options.first, 0.5);
    expect(PlaybackSpeed.options.last, 2.0);
    expect(PlaybackSpeed.options, contains(1.0));
  });

  test('speeds are written in Arabic digits, with an Arabic decimal mark', () {
    expect(PlaybackSpeed.label(1.0), '١');
    expect(PlaybackSpeed.label(1.5), '١٫٥');
    expect(PlaybackSpeed.label(0.75), '٠٫٧٥');
    expect(PlaybackSpeed.label(2.0), '٢');
  });

  test('the reading voice follows the same setting, and stays sayable',
      () async {
    await PlaybackSpeed.set(1.0);
    expect(PlaybackSpeed.speechRate, closeTo(0.45, 0.001));

    await PlaybackSpeed.set(0.5);
    expect(PlaybackSpeed.speechRate, lessThan(0.45));

    // The engine takes 0..1; double speed must not ask for more than it can.
    await PlaybackSpeed.set(2.0);
    expect(PlaybackSpeed.speechRate, lessThanOrEqualTo(1.0));
    expect(PlaybackSpeed.speechRate, greaterThan(0.45));
  });

  test('a broadcast is marked live and does not carry the reader\'s speed',
      () async {
    await PlaybackSpeed.set(1.75);
    await PlaybackSpeed.apply(live: true);
    expect(PlaybackSpeed.isLive, isTrue);
    // The setting itself is untouched: leaving the radio returns to it.
    expect(PlaybackSpeed.value.value, 1.75);

    await PlaybackSpeed.apply();
    expect(PlaybackSpeed.isLive, isFalse);
  });
}
