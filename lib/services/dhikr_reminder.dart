import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/adhans.dart';
import '../data/adhkar_data.dart';
import '../data/quran_data.dart';
import 'notification_service.dart';
import 'prayer_alerts.dart';

/// When the reminders arrive: on a rhythm of their own, or before the prayers.
enum DhikrRhythm {
  spread('موزّعة على اليوم', 'عدد ثابت، بمسافات متساوية'),
  beforePrayer('قبل كل صلاة', 'ذكر يسبق الأذان بوقت تختاره');

  final String label;
  final String note;
  const DhikrRhythm(this.label, this.note);

  static DhikrRhythm byId(String? id) =>
      values.where((r) => r.name == id).firstOrNull ?? spread;
}

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
  static const _rhythmKey = '@noor_dhikr_reminder_rhythm';
  static const _leadKey = '@noor_dhikr_reminder_lead';

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

  /// Spread through the day, or tied to the prayers.
  static final rhythm = ValueNotifier<DhikrRhythm>(DhikrRhythm.spread);

  /// How long before the adhan the dhikr arrives.
  static final lead = ValueNotifier<int>(45);

  static const leadChoices = [15, 30, 45, 60];

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_enabledKey) ?? false;
      perDay.value = prefs.getInt(_countKey) ?? 5;
      fromHour.value = prefs.getInt(_fromKey) ?? 8;
      toHour.value = prefs.getInt(_toKey) ?? 22;
      flavour.value = DhikrFlavour.byId(prefs.getString(_flavourKey));
      rhythm.value = DhikrRhythm.byId(prefs.getString(_rhythmKey));
      final storedLead = prefs.getInt(_leadKey) ?? 45;
      lead.value = leadChoices.contains(storedLead) ? storedLead : 45;
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
    DhikrRhythm? beat,
    int? minutesBefore,
  }) async {
    if (on != null) enabled.value = on;
    if (count != null) perDay.value = count;
    if (from != null) fromHour.value = from;
    if (to != null) toHour.value = to;
    if (kind != null) flavour.value = kind;
    if (beat != null) rhythm.value = beat;
    if (minutesBefore != null) lead.value = minutesBefore;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, enabled.value);
      await prefs.setInt(_countKey, perDay.value);
      await prefs.setInt(_fromKey, fromHour.value);
      await prefs.setInt(_toKey, toHour.value);
      await prefs.setString(_flavourKey, flavour.value.id);
      await prefs.setString(_rhythmKey, rhythm.value.name);
      await prefs.setInt(_leadKey, lead.value);
    } catch (_) {
      // The schedule below still reflects the choice for this session.
    }
    await reschedule();
  }

  /// The times reminders land.
  ///
  /// Spread evenly rather than randomly: a reader who knows roughly when one
  /// is due can be ready for it, and randomness only ever looks like a fault.
  static List<int> slotMinutes() {
    if (rhythm.value == DhikrRhythm.beforePrayer) {
      final anchored = _beforePrayers();
      // Until the prayer times are known — a first run, or a reader who never
      // granted the location — the reminders keep the even rhythm rather than
      // stopping. Silence would look like the setting did nothing.
      if (anchored.isNotEmpty) return anchored;
    }

    final start = fromHour.value * 60;
    final end = toHour.value * 60;
    if (end <= start || perDay.value < 1) return const [];
    final step = (end - start) ~/ perDay.value;
    return [for (var i = 0; i < perDay.value; i++) start + step ~/ 2 + i * step];
  }

  /// A slot [lead] minutes before each of the five prayers, as minutes past
  /// midnight.
  ///
  /// Sunrise is not among them, since it is not a prayer. A prayer close
  /// enough to midnight that the lead crosses it — Isha in a northern summer —
  /// wraps to the same clock time on the previous day, which is where the
  /// reader would expect the reminder to arrive.
  static List<int> _beforePrayers() {
    final times = PrayerAlerts.lastTimes;
    if (times.isEmpty) return const [];

    final slots = <int>{};
    for (final at in times.values) {
      final minutes = at.hour * 60 + at.minute - lead.value;
      slots.add(minutes < 0 ? minutes + 24 * 60 : minutes);
    }
    return slots.toList()..sort();
  }

  /// The adhkar short enough to read at a glance on a lock screen, of the kind
  /// the reader asked for. A long supplication truncated by the system is
  /// worse than not sending it.
  /// Matches a kind against a dhikr with both sides stripped of what the
  /// reader never sees as a difference.
  ///
  /// The adhkar are stored fully vowelled — اللَّهُمَّ — and every marker here is
  /// written plainly — اللهم. So a raw `contains` matched nothing at all, for
  /// any kind, and the "never return an empty pool" fallback quietly handed
  /// back every short dhikr instead. The chips looked like they worked and
  /// none of them did: asking for supplications sent tasbih.
  static bool _carries(Dhikr dhikr, String marker) =>
      QuranService.searchKey(dhikr.text)
          .contains(QuranService.searchKey(marker));

  static List<Dhikr> get pool {
    final short = adhkar.where((d) => d.text.length <= 90).toList();
    final marker = flavour.value.marker;

    if (flavour.value == DhikrFlavour.all) return short;

    if (marker != null) {
      final matched = short.where((d) => _carries(d, marker)).toList();
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
        short.where((d) => !named.any((m) => _carries(d, m))).toList();
    return rest.isEmpty ? short : rest;
  }

  /// Lays the reminders down again.
  ///
  /// A failure here — the plugin unavailable, the system refusing an alarm —
  /// must not throw out of the settings tap that caused it: the reader's
  /// choice is already saved, and losing the screen over a schedule that can
  /// be rebuilt on the next launch would be the worse trade.
  /// The gap between one reminder and the next, in minutes.
  ///
  /// Twelve reminders inside a one-hour window is one every five minutes, all
  /// of them before dawn. The setting allowed it and said nothing, so the
  /// reader saw no reminders and reasonably concluded they were broken.
  static int get spacing {
    final slots = slotMinutes();
    if (slots.length < 2) return 0;
    return slots[1] - slots[0];
  }

  /// True when the window cannot hold the count without crowding them.
  static bool get isCrowded => spacing > 0 && spacing < 20;

  static Future<void> reschedule() async {
    try {
      await NotificationService.scheduleDhikrReminders(
        enabled: enabled.value,
        minutes: slotMinutes(),
        pool: pool,
      );
    } catch (_) {
      // Rebuilt at the next launch, and at the next prayer-times load.
    }
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
