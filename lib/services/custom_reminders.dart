import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What a reminder points at: a surah to read, or a set of adhkar.
enum ReminderKind { surah, adhkar }

/// One reminder the reader set up themselves: a surah or adhkar category, on
/// the weekdays they picked, at one or more times on each of those days.
@immutable
class CustomReminder {
  /// Stable for the reminder's life; its notification ids derive from it.
  final int id;
  final ReminderKind kind;

  /// Surah number (1–114) when [kind] is [ReminderKind.surah].
  final int? surah;

  /// Adhkar category id (as in adhkar_data's categories) when [kind] is
  /// [ReminderKind.adhkar].
  final String? adhkarId;

  /// DateTime weekdays: 1 = Monday … 7 = Sunday.
  final Set<int> days;

  /// Minutes after midnight, one per alert on each chosen day.
  final List<int> times;
  final bool enabled;

  const CustomReminder({
    required this.id,
    required this.kind,
    this.surah,
    this.adhkarId,
    required this.days,
    required this.times,
    this.enabled = true,
  });

  /// What a tap on the notification opens: "surah:18" or "adhkar:morning".
  String get payload =>
      kind == ReminderKind.surah ? 'surah:$surah' : 'adhkar:$adhkarId';

  CustomReminder copyWith({
    ReminderKind? kind,
    int? surah,
    String? adhkarId,
    Set<int>? days,
    List<int>? times,
    bool? enabled,
  }) => CustomReminder(
    id: id,
    kind: kind ?? this.kind,
    surah: surah ?? this.surah,
    adhkarId: adhkarId ?? this.adhkarId,
    days: days ?? this.days,
    times: times ?? this.times,
    enabled: enabled ?? this.enabled,
  );

  /// The same reminder under another id (a suggestion being saved).
  CustomReminder copyWithId(int newId) => CustomReminder(
    id: newId,
    kind: kind,
    surah: surah,
    adhkarId: adhkarId,
    days: days,
    times: times,
    enabled: enabled,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    if (surah != null) 'surah': surah,
    if (adhkarId != null) 'adhkar': adhkarId,
    'days': days.toList()..sort(),
    'times': times,
    'on': enabled,
  };

  factory CustomReminder.fromJson(Map<String, dynamic> j) => CustomReminder(
    id: j['id'] as int,
    kind: ReminderKind.values.byName(j['kind'] as String),
    surah: j['surah'] as int?,
    adhkarId: j['adhkar'] as String?,
    days: {for (final d in j['days'] as List) d as int},
    times: [for (final t in j['times'] as List) t as int],
    enabled: j['on'] as bool? ?? true,
  );

  /// The notification id for one alert: [weekday] 1–7, [slot] its index in
  /// [times]. Kept clear of the app's other ranges (1–2, 100–411, 900s,
  /// 1000–1941).
  static int notificationId(int reminderId, int weekday, int slot) =>
      firstNotificationId + reminderId * 100 + weekday * 10 + slot;

  static const firstNotificationId = 10000;

  /// At most this many times a day, so a reminder's ids never spill into
  /// the next weekday's.
  static const maxTimes = 6;
}

/// The reader's own reminders, kept on the device.
class CustomReminders {
  CustomReminders._();

  static const _key = '@noor_custom_reminders';

  static final list = ValueNotifier<List<CustomReminder>>(const []);

  /// Set by main: lays every reminder down again after any change.
  static Future<void> Function()? onChanged;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      list.value = [
        for (final j in jsonDecode(raw) as List)
          CustomReminder.fromJson(j as Map<String, dynamic>),
      ];
    } catch (_) {
      // Unreadable: start empty rather than crash the app over reminders.
    }
  }

  static int nextId() => list.value.isEmpty
      ? 1
      : list.value.map((r) => r.id).reduce((a, b) => a > b ? a : b) + 1;

  static Future<void> save(CustomReminder reminder) async {
    final others = list.value.where((r) => r.id != reminder.id);
    list.value = [...others, reminder]..sort((a, b) => a.id.compareTo(b.id));
    await _persist();
  }

  static Future<void> remove(int id) async {
    list.value = list.value.where((r) => r.id != id).toList();
    await _persist();
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode([for (final r in list.value) r.toJson()]),
      );
    } catch (_) {
      // Holds for this session even if storage failed.
    }
    await onChanged?.call();
  }
}
