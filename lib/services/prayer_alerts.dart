import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How an alert arrives.
///
/// Notification-and-vibration and sound are separate switches rather than
/// three exclusive choices, because a reader may well want both — the phone in
/// a pocket buzzing *and* the adhan playing — and forcing a pick between them
/// makes the louder option quieter than the quiet one.
class AlertMode {
  final bool notify;
  final bool sound;

  const AlertMode({this.notify = false, this.sound = false});

  static const off = AlertMode();

  bool get isOff => !notify && !sound;

  /// Something has to arrive for a sound to arrive with it, so choosing sound
  /// implies the notification that carries it.
  AlertMode withSound(bool on) =>
      AlertMode(notify: on ? true : notify, sound: on);

  AlertMode withNotify(bool on) =>
      AlertMode(notify: on, sound: on ? sound : false);

  String get label {
    if (isOff) return 'مغلق';
    if (notify && sound) return 'إشعار وصوت';
    return sound ? 'صوت' : 'إشعار واهتزاز';
  }

  String encode() => '${notify ? 1 : 0}${sound ? 1 : 0}';

  static AlertMode decode(String? raw) {
    // The old format stored one of three names; a reader upgrading keeps what
    // they had rather than being silently switched off.
    switch (raw) {
      case 'off':
        return off;
      case 'notify':
        return const AlertMode(notify: true);
      case 'sound':
        return const AlertMode(notify: true, sound: true);
    }
    if (raw == null || raw.length != 2) return off;
    return AlertMode(notify: raw[0] == '1', sound: raw[1] == '1');
  }
}

/// The two moments a prayer can be announced at.
enum AlertWhen {
  before('before', 'التنبيه قبل الصلاة'),
  onTime('on_time', 'التنبيه وقت الصلاة');

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

/// Every prayer's two alerts, how far ahead the early one comes, and which
/// adhan plays.
class PrayerAlerts {
  static const _key = '@noor_prayer_alerts';
  static const _leadKey = '@noor_prayer_alert_lead';
  static const _adhanKey = '@noor_prayer_adhan';

  /// Screens listen so a change shows without a reload.
  static final settings = ValueNotifier<Map<String, AlertMode>>(const {});

  /// Minutes before the prayer that the early alert fires.
  static final lead = ValueNotifier<int>(15);

  /// Which adhan plays at prayer time, by [Adhan.id].
  static final adhan = ValueNotifier<String>('makkah');

  static const leadChoices = [5, 10, 15, 20, 30, 45];

  /// The last computed prayer times, so a setting changed in the settings
  /// screen can take effect at once instead of waiting for the next load.
  static Map<AlertPrayer, DateTime> lastTimes = const {};

  /// Set at startup. Kept as a hook rather than an import so this file stays
  /// unaware of the notification plumbing.
  static Future<void> Function(Map<AlertPrayer, DateTime>)? onChanged;

  static Future<void> _reschedule() async {
    if (lastTimes.isEmpty) return;
    await onChanged?.call(lastTimes);
  }

  static String keyFor(AlertPrayer prayer, AlertWhen when) =>
      '${prayer.id}_${when.id}';

  static AlertMode modeFor(AlertPrayer prayer, AlertWhen when) =>
      settings.value[keyFor(prayer, when)] ?? AlertMode.off;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      lead.value = prefs.getInt(_leadKey) ?? 15;
      adhan.value = prefs.getString(_adhanKey) ?? 'makkah';
      final raw = prefs.getString(_key);
      // Reset rather than return: loading must land on what is stored, and
      // "nothing is stored" means nothing is set.
      if (raw == null) {
        settings.value = const {};
        return;
      }
      final decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
      settings.value = {
        for (final entry in decoded.entries)
          entry.key: AlertMode.decode(entry.value as String?),
      };
    } catch (_) {
      // Silence is the safe default: nothing announces itself unasked.
    }
  }

  static Future<void> setMode(
      AlertPrayer prayer, AlertWhen when, AlertMode mode) async {
    settings.value = {...settings.value, keyFor(prayer, when): mode};
    await _persist();
    await _reschedule();
  }

  /// Applies one mode to all five prayers at a given moment — the row header
  /// sets the column, since a reader almost always wants the same everywhere.
  static Future<void> setAll(AlertWhen when, AlertMode mode) async {
    settings.value = {
      ...settings.value,
      for (final prayer in AlertPrayer.values) keyFor(prayer, when): mode,
    };
    await _persist();
    await _reschedule();
  }

  static Future<void> setLead(int minutes) async {
    lead.value = minutes;
    await _save((p) => p.setInt(_leadKey, minutes));
    await _reschedule();
  }

  static Future<void> setAdhan(String id) async {
    adhan.value = id;
    await _save((p) => p.setString(_adhanKey, id));
    await _reschedule();
  }

  /// Strips every sound everywhere, leaving the notifications in place — the
  /// single switch at the top of settings.
  static Future<void> muteEverything() async {
    settings.value = {
      for (final entry in settings.value.entries)
        entry.key: entry.value.withSound(false),
    };
    await _persist();
    await _reschedule();
  }

  /// The raw resource name for the chosen adhan, or null when it is one of
  /// the downloadable ones — those cannot be a notification sound until they
  /// are copied in, so until then the alert keeps the system tone rather than
  /// falling silent.
  static String? get bundledResource => switch (adhan.value) {
        'makkah' => 'adhan_makkah',
        'madinah' => 'adhan_madinah',
        _ => null,
      };

  static bool get anySound =>
      settings.value.values.any((m) => m.sound);

  static bool get anyOn => settings.value.values.any((m) => !m.isOff);

  static Future<void> _persist() => _save((prefs) => prefs.setString(
        _key,
        jsonEncode({
          for (final e in settings.value.entries) e.key: e.value.encode(),
        }),
      ));

  static Future<void> _save(Future<void> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // The change still applies to this session.
    }
  }
}
