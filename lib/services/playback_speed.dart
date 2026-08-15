import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_audio.dart';

/// How fast the app plays what it plays.
///
/// One setting for the whole app rather than one per screen: a reader who
/// slows a recitation down to follow it wants the dhikr and the lesson slowed
/// too, and would not think to set it three times. It is remembered, so the
/// choice survives closing the app.
///
/// A broadcast is the exception. A live stream has no timeline to compress —
/// speeding it up only empties the buffer — so the radio plays at its own pace
/// and says so by hiding the control.
class PlaybackSpeed {
  static const _key = '@noor_playback_speed';

  static const options = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

  static final value = ValueNotifier<double>(1.0);

  /// True while a live stream holds the player.
  static bool _live = false;

  static bool get isLive => _live;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getDouble(_key);
      // An unknown value — a hand-edited store, or a build with other steps —
      // reads as normal speed rather than something the picker cannot show.
      if (stored != null && options.contains(stored)) value.value = stored;
    } catch (_) {
      // Normal speed is the safe default.
    }
  }

  static Future<void> set(double speed) async {
    value.value = speed;
    await _applyToPlayer();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_key, speed);
    } catch (_) {
      // The change still holds for this session.
    }
  }

  /// Called by whatever just loaded a source. [live] marks a broadcast, which
  /// always plays at its own speed.
  static Future<void> apply({bool live = false}) async {
    _live = live;
    await _applyToPlayer();
  }

  static Future<void> _applyToPlayer() async {
    try {
      await AppAudio.player.setSpeed(_live ? 1.0 : value.value);
    } catch (_) {
      // Speed is a convenience; failing to set it must not stop the sound.
    }
  }

  /// The reading rate for the device's voice, which counts 1.0 as very fast —
  /// 0.45 is the pace the app reads at normally, and the reader's choice
  /// scales it.
  static double get speechRate => (0.45 * value.value).clamp(0.1, 1.0);

  /// '١٫٥' rather than '1.5': the app counts in Arabic digits everywhere else.
  static String label(double speed) {
    final plain = speed == speed.roundToDouble()
        ? speed.toInt().toString()
        : speed.toString();
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return plain.split('').map((c) {
      if (c == '.') return '٫';
      final digit = int.tryParse(c);
      return digit == null ? c : arabic[digit];
    }).join();
  }
}
