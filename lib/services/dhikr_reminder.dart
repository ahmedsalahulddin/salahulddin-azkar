import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/adhans.dart';
import '../data/adhkar_data.dart';
import 'notification_service.dart';

/// A short dhikr that arrives on the phone through the day.
///
/// Deliberately not a single dhikr repeated: the same words at the same hour
/// become furniture within a week, and a reminder nobody reads is worse than
/// none. The reader picks how often, and the app rotates through the short
/// adhkar so each arrival says something.
class DhikrReminder {
  static const _enabledKey = '@noor_dhikr_reminder';
  static const _countKey = '@noor_dhikr_reminder_count';
  static const _fromKey = '@noor_dhikr_reminder_from';
  static const _toKey = '@noor_dhikr_reminder_to';
  static const _flavourKey = '@noor_dhikr_reminder_flavour';

  static final enabled = ValueNotifier<bool>(false);

  /// Reminders per day, spread evenly across the waking window.
  static final perDay = ValueNotifier<int>(5);

  /// The hours between which reminders may arrive — nobody wants a buzz at
  /// three in the morning.
  static final fromHour = ValueNotifier<int>(8);
  static final toHour = ValueNotifier<int>(22);

  /// Which kind of dhikr arrives. "All" by default — a reader who has not
  /// chosen has not asked to be narrowed.
  static final flavour = ValueNotifier<DhikrFlavour>(DhikrFlavour.all);

  static const countChoices = [3, 5, 8, 12];

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_enabledKey) ?? false;
      perDay.value = prefs.getInt(_countKey) ?? 5;
      fromHour.value = prefs.getInt(_fromKey) ?? 8;
      toHour.value = prefs.getInt(_toKey) ?? 22;
      flavour.value = DhikrFlavour.byId(prefs.getString(_flavourKey));
    } catch (_) {
      // Off is the safe default: nothing arrives unasked.
    }
  }

  static Future<void> apply({
    bool? on,
    int? count,
    int? from,
    int? to,
    DhikrFlavour? kind,
  }) async {
    if (on != null) enabled.value = on;
    if (count != null) perDay.value = count;
    if (from != null) fromHour.value = from;
    if (to != null) toHour.value = to;
    if (kind != null) flavour.value = kind;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled.value);
      await prefs.setInt(_countKey, perDay.value);
      await prefs.setInt(_fromKey, fromHour.value);
      await prefs.setInt(_toKey, toHour.value);
      await prefs.setString(_flavourKey, flavour.value.id);
    } catch (_) {
      // The schedule below still reflects the choice for this session.
    }
    await reschedule();
  }

  /// The times reminders land, spread evenly through the waking window.
  ///
  /// Evenly rather than randomly: a reader who knows roughly when one is due
  /// can be ready for it, and randomness only ever looks like a fault.
  static List<int> slotMinutes() {
    final start = fromHour.value * 60;
    final end = toHour.value * 60;
    if (end <= start || perDay.value < 1) return const [];
    final step = (end - start) ~/ perDay.value;
    return [for (var i = 0; i < perDay.value; i++) start + step ~/ 2 + i * step];
  }

  /// The adhkar short enough to read at a glance on a lock screen, of the kind
  /// the reader asked for. A long supplication truncated by the system is
  /// worse than not sending it.
  static List<Dhikr> get pool {
    final short = adhkar.where((d) => d.text.length <= 90).toList();
    final marker = flavour.value.marker;

    if (flavour.value == DhikrFlavour.all) return short;

    if (marker != null) {
      final matched = short.where((d) => d.text.contains(marker)).toList();
      // Never return nothing: a filter that empties the pool would silence
      // the reminder without saying so.
      return matched.isEmpty ? short : matched;
    }

    // "Various adhkar" is whatever the named kinds leave over.
    final named = [
      for (final f in DhikrFlavour.values)
        if (f.marker != null) f.marker!,
    ];
    final rest =
        short.where((d) => !named.any((m) => d.text.contains(m))).toList();
    return rest.isEmpty ? short : rest;
  }

  static Future<void> reschedule() =>
      NotificationService.scheduleDhikrReminders(
        enabled: enabled.value,
        minutes: slotMinutes(),
        pool: pool,
      );
}
