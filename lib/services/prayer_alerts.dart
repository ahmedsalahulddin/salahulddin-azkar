import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How loudly a prayer announces itself.
enum AlertMode {
  off('off', 'إقفال', '🚫'),
  notify('notify', 'إشعار واهتزاز', '📳'),
  sound('sound', 'صوت', '🔔');

  const AlertMode(this.id, this.label, this.icon);

  final String id;
  final String label;
  final String icon;

  static AlertMode byId(String? id) =>
      values.firstWhere((m) => m.id == id, orElse: () => off);

  bool get vibrates => this != AlertMode.off;
  bool get plays => this == AlertMode.sound;
}

/// The two moments a prayer can be announced at.
enum AlertWhen {
  before('before', 'تنبيه قبل الصلاة'),
  onTime('on_time', 'وقت الصلاة');

  const AlertWhen(this.id, this.label);

  final String id;
  final String label;
}

/// The five prayers that get announced. Sunrise is not among them: it is not a
/// prayer, and an alarm for it would call people to something that is not
/// there.
enum AlertPrayer {
  fajr('fajr', 'الفجر'),
  dhuhr('dhuhr', 'الظهر'),
  asr('asr', 'العصر'),
  maghrib('maghrib', 'المغرب'),
  isha('isha', 'العشاء');

  const AlertPrayer(this.id, this.name);

  final String id;
  final String name;
}

/// Every prayer's two alerts, and how many minutes ahead the early one comes.
///
/// Ten rows of state, so it is stored as one JSON blob rather than twenty
/// preference keys — a shape that survives adding a prayer or a moment later
/// without a migration.
class PrayerAlerts {
  static const _key = '@noor_prayer_alerts';
  static const _leadKey = '@noor_prayer_alert_lead';

  /// Screens listen so a change shows without a reload.
  static final settings =
      ValueNotifier<Map<String, AlertMode>>(const {});

  /// Minutes before the prayer that the early alert fires.
  static final lead = ValueNotifier<int>(15);

  static const leadChoices = [5, 10, 15, 20, 30];

  static String keyFor(AlertPrayer prayer, AlertWhen when) =>
      '${prayer.id}_${when.id}';

  static AlertMode modeFor(AlertPrayer prayer, AlertWhen when) =>
      settings.value[keyFor(prayer, when)] ?? AlertMode.off;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      lead.value = prefs.getInt(_leadKey) ?? 15;
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
      settings.value = {
        for (final entry in decoded.entries)
          entry.key: AlertMode.byId(entry.value as String?),
      };
    } catch (_) {
      // Silence is the safe default: nothing announces itself unasked.
    }
  }

  static Future<void> setMode(
      AlertPrayer prayer, AlertWhen when, AlertMode mode) async {
    settings.value = {
      ...settings.value,
      keyFor(prayer, when): mode,
    };
    await _persist();
  }

  static Future<void> setLead(int minutes) async {
    lead.value = minutes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_leadKey, minutes);
    } catch (_) {
      // Applies to this session regardless.
    }
  }

  static Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          for (final entry in settings.value.entries) entry.key: entry.value.id,
        }),
      );
    } catch (_) {
      // Applies to this session regardless.
    }
  }

  /// True when anything at all is set to announce itself — used to decide
  /// whether the schedule is worth rebuilding.
  static bool get anyOn =>
      settings.value.values.any((m) => m != AlertMode.off);
}
