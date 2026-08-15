import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A time of day, stored as minutes past midnight so it survives a timezone
/// change without meaning something else.
class DayTime {
  final int minutes;

  const DayTime(this.minutes);

  int get hour => minutes ~/ 60;
  int get minute => minutes % 60;

  DayTime clampTo(int earliest, int latest) =>
      DayTime(minutes.clamp(earliest, latest));

  String get label {
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${minute.toString().padLeft(2, '0')} ${hour >= 12 ? 'م' : 'ص'}';
  }
}

/// The reminders that arrive at a chosen hour rather than on a rhythm: the
/// verse and hadith pair, and the morning and evening adhkar.
///
/// Each carries a window it must stay inside. Morning adhkar are said between
/// Fajr and Dhuhr, so the setting cannot leave that span; evening adhkar
/// between Asr and Maghrib. Clamping in the model rather than the picker means
/// a value that arrives from anywhere — an old install, a hand-edited store —
/// is still a time the adhkar can actually be said at.
class DailyReminders {
  static const _keys = {
    'verse_on': '@noor_verse_on',
    'verse_a': '@noor_verse_first',
    'verse_b': '@noor_verse_second',
    'morning_on': '@noor_morning_on',
    'morning_at': '@noor_morning_at',
    'evening_on': '@noor_evening_on',
    'evening_at': '@noor_evening_at',
  };

  // ---- verse and hadith, twice a day -------------------------------------

  static final verseOn = ValueNotifier<bool>(false);

  /// Two hours before Dhuhr, and two and a half after Isha — the defaults the
  /// reader asked for, expressed as clock times since the reminder is laid
  /// down before the day's prayer times are known.
  static final verseFirst = ValueNotifier<DayTime>(const DayTime(10 * 60));
  static final verseSecond = ValueNotifier<DayTime>(const DayTime(22 * 60 + 30));

  // ---- morning and evening adhkar ----------------------------------------

  static final morningOn = ValueNotifier<bool>(false);
  static final eveningOn = ValueNotifier<bool>(false);

  static final morningAt = ValueNotifier<DayTime>(const DayTime(6 * 60));
  static final eveningAt = ValueNotifier<DayTime>(const DayTime(17 * 60));

  /// Morning adhkar run from Fajr to just before noon; the reader asked for
  /// 11:59 as the hard stop.
  static const morningWindow = (earliest: 4 * 60, latest: 11 * 60 + 59);

  /// Evening adhkar run from Asr to Maghrib.
  static const eveningWindow = (earliest: 15 * 60, latest: 19 * 60 + 30);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      int? at(String key) => prefs.getInt(_keys[key]!);

      verseOn.value = prefs.getBool(_keys['verse_on']!) ?? false;
      verseFirst.value = DayTime(at('verse_a') ?? 10 * 60);
      verseSecond.value = DayTime(at('verse_b') ?? 22 * 60 + 30);

      morningOn.value = prefs.getBool(_keys['morning_on']!) ?? false;
      eveningOn.value = prefs.getBool(_keys['evening_on']!) ?? false;
      morningAt.value = DayTime(at('morning_at') ?? 6 * 60)
          .clampTo(morningWindow.earliest, morningWindow.latest);
      eveningAt.value = DayTime(at('evening_at') ?? 17 * 60)
          .clampTo(eveningWindow.earliest, eveningWindow.latest);
    } catch (_) {
      // Off is the safe default: nothing arrives unasked.
    }
  }

  static Future<void> setVerse({bool? on, DayTime? first, DayTime? second}) async {
    if (on != null) verseOn.value = on;
    if (first != null) verseFirst.value = first;
    if (second != null) verseSecond.value = second;
    await _persist();
  }

  static Future<void> setMorning({bool? on, DayTime? at}) async {
    if (on != null) morningOn.value = on;
    if (at != null) {
      morningAt.value =
          at.clampTo(morningWindow.earliest, morningWindow.latest);
    }
    await _persist();
  }

  static Future<void> setEvening({bool? on, DayTime? at}) async {
    if (on != null) eveningOn.value = on;
    if (at != null) {
      eveningAt.value =
          at.clampTo(eveningWindow.earliest, eveningWindow.latest);
    }
    await _persist();
  }

  /// Set at startup, so this file stays unaware of the notification plumbing.
  static Future<void> Function()? onChanged;

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keys['verse_on']!, verseOn.value);
      await prefs.setInt(_keys['verse_a']!, verseFirst.value.minutes);
      await prefs.setInt(_keys['verse_b']!, verseSecond.value.minutes);
      await prefs.setBool(_keys['morning_on']!, morningOn.value);
      await prefs.setInt(_keys['morning_at']!, morningAt.value.minutes);
      await prefs.setBool(_keys['evening_on']!, eveningOn.value);
      await prefs.setInt(_keys['evening_at']!, eveningAt.value.minutes);
    } catch (_) {
      // The change still applies to this session.
    }
    await onChanged?.call();
  }
}
