import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One adjustable number of the page border.
///
/// Each is an offset from what the app draws on its own, so zero everywhere is
/// exactly the built-in look and "إعادة الضبط" is a real return rather than a
/// second guess at it.
class FrameKnob {
  final String id;
  final String label;
  final String note;
  final double min;
  final double max;
  final double normal;

  const FrameKnob({
    required this.id,
    required this.label,
    required this.note,
    required this.min,
    required this.max,
    required this.normal,
  });
}

/// Where the border sits, in the reader's own hands.
///
/// Phones differ in how much taller than wide they are, in where the system
/// bars end, and in how much of the printed page the image covers. A border
/// tuned on one can sit wrong on another, and describing "wrong" over
/// screenshots is slow and lossy. So the numbers are exposed: the reader
/// drags, watches the page behind the panel, and stops when it looks right.
class FrameTuning {
  static const knobs = <FrameKnob>[
    FrameKnob(
      id: 'top',
      label: 'من فوق',
      note: 'المسافة بين الإطار وأول سطر',
      min: -40,
      max: 60,
      normal: 0,
    ),
    FrameKnob(
      id: 'bottom',
      label: 'من تحت',
      note: 'المسافة بين الإطار وآخر سطر',
      min: -40,
      max: 60,
      normal: 0,
    ),
    FrameKnob(
      id: 'side',
      label: 'الجانبان',
      note: 'كم يظهر من الإطار يميناً ويساراً',
      min: -30,
      max: 60,
      normal: 0,
    ),
    FrameKnob(
      id: 'scale',
      label: 'حجم الزخرفة',
      note: 'غِلَظ الإطار ونقشه',
      min: 0.5,
      max: 1.8,
      normal: 1,
    ),
    FrameKnob(
      id: 'header',
      label: 'اسم السورة والجزء',
      note: 'ارتفاعهما داخل الإطار',
      min: -30,
      max: 30,
      normal: 0,
    ),
    FrameKnob(
      id: 'number',
      label: 'رقم الصفحة',
      note: 'ارتفاعه داخل الإطار',
      min: -30,
      max: 30,
      normal: 0,
    ),
    FrameKnob(
      id: 'caption',
      label: 'حجم الكتابة',
      note: 'خط اسم السورة والجزء والرقم',
      min: 10,
      max: 26,
      normal: 16,
    ),
  ];

  /// Bumped on every change, so the page redraws while the panel is open.
  static final revision = ValueNotifier<int>(0);

  static final Map<String, double> _values = {
    for (final knob in knobs) knob.id: knob.normal,
  };

  static double of(String id) =>
      _values[id] ?? knobs.firstWhere((k) => k.id == id).normal;

  static bool get isDefault =>
      knobs.every((k) => (of(k.id) - k.normal).abs() < 0.001);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final knob in knobs) {
        final stored = prefs.getDouble('@noor_frame_${knob.id}');
        if (stored == null) continue;
        // A value from a build with different limits is brought inside them
        // rather than trusted: a border 400 pixels off the page is not a
        // border anyone can find again to fix.
        _values[knob.id] = stored.clamp(knob.min, knob.max);
      }
    } catch (_) {
      // The built-in look is the safe default.
    }
    revision.value++;
  }

  static Future<void> set(String id, double value) async {
    final knob = knobs.firstWhere((k) => k.id == id);
    _values[id] = value.clamp(knob.min, knob.max);
    revision.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('@noor_frame_$id', _values[id]!);
    } catch (_) {
      // The change still holds for this session.
    }
  }

  static Future<void> reset() async {
    for (final knob in knobs) {
      _values[knob.id] = knob.normal;
    }
    revision.value++;
    try {
      final prefs = await SharedPreferences.getInstance();
      for (final knob in knobs) {
        await prefs.remove('@noor_frame_${knob.id}');
      }
    } catch (_) {
      // Reset for this session regardless.
    }
  }

  /// The numbers as one line, for a reader who wants their settings made the
  /// app's own defaults and has to get them to whoever can do that.
  static String asText() => [
        for (final knob in knobs)
          '${knob.id}=${of(knob.id).toStringAsFixed(1)}',
      ].join('، ');

  @visibleForTesting
  static void debugReset() {
    for (final knob in knobs) {
      _values[knob.id] = knob.normal;
    }
    revision.value = 0;
  }
}
