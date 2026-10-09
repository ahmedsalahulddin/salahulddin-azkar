import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/adhans.dart';
import '../l10n/strings.dart';
import 'app_locale.dart';
import 'prayer_service.dart' show prayerNameIn;

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

  // A value, so two of them holding the same two answers are the same thing.
  // Without this the class was compared by identity, and any check that two
  // alerts matched was quietly always false.
  @override
  bool operator ==(Object other) =>
      other is AlertMode && other.notify == notify && other.sound == sound;

  @override
  int get hashCode => Object.hash(notify, sound);

  @override
  String toString() => 'AlertMode(notify: $notify, sound: $sound)';

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

  /// [label] in the reader's language.
  String get displayLabel =>
      t(this == AlertWhen.before ? 'adh.whenBefore' : 'adh.whenOnTime');
}

/// The five prayers that get announced. Sunrise is not among them: it is not a
/// prayer, and an alarm for it would call people to something that is not
/// there.
enum AlertPrayer {
  fajr('fajr', 'الفجر', 'Fajr'),
  dhuhr('dhuhr', 'الظهر', 'Dhuhr'),
  asr('asr', 'العصر', 'Asr'),
  maghrib('maghrib', 'المغرب', 'Maghrib'),
  isha('isha', 'العشاء', 'Isha');

  const AlertPrayer(this.id, this.name, this.nameEn);

  final String id;

  /// Arabic name. Kept as `name`, shadowing [Enum.name], for the many
  /// existing call sites that predate [displayName].
  final String name;
  final String nameEn;

  /// What the reader actually sees — the one to use in UI text.
  String get displayName => prayerNameIn(AppLocale.code, name, nameEn);
}

/// Every prayer's two alerts, how far ahead the early one comes, and which
/// adhan plays.
class PrayerAlerts {
  static const _key = '@noor_prayer_alerts';
  static const _leadKey = '@noor_prayer_alert_lead';
  static const _adhanKey = '@noor_prayer_adhan';

  /// What the alerts sounded like before they were silenced, so that turning
  /// the silence off is a return rather than a guess.
  static const _beforeMuteKey = '@noor_prayer_alerts_premute';

  /// Screens listen so a change shows without a reload.
  static final settings = ValueNotifier<Map<String, AlertMode>>(const {});

  /// Minutes before the prayer that the early alert fires.
  static final lead = ValueNotifier<int>(15);

  /// Which adhan plays at prayer time, by [Adhan.id].
  static final adhan = ValueNotifier<String>(Adhans.defaultId);

  static const leadChoices = [5, 10, 15, 20, 30, 45];

  /// Jumu'ah is not prepared for like Dhuhr — ghusl, perfume, setting out
  /// early — so on Fridays Dhuhr's early warning is replaced by one of its
  /// own, set apart and further ahead.
  static const fridayKey = 'jumuah_before';
  static const _fridayLeadKey = '@noor_prayer_friday_lead';
  static final fridayLead = ValueNotifier<int>(60);
  static const fridayLeadChoices = [30, 45, 60, 90, 120];

  static AlertMode get fridayMode => settings.value[fridayKey] ?? AlertMode.off;

  /// Dhuhr on a Friday — the time of Jumu'ah.
  static bool isJumuah(AlertPrayer prayer, DateTime at) =>
      prayer == AlertPrayer.dhuhr && at.weekday == DateTime.friday;

  /// What an alert actually does at [at]: on a Friday, Dhuhr's early warning
  /// follows the Jumu'ah row instead of the Dhuhr one.
  static AlertMode modeAt(AlertPrayer prayer, AlertWhen when, DateTime at) =>
      when == AlertWhen.before && isJumuah(prayer, at)
      ? fridayMode
      : modeFor(prayer, when);

  /// Minutes ahead the early warning comes at [at].
  static int leadAt(AlertPrayer prayer, DateTime at) =>
      isJumuah(prayer, at) ? fridayLead.value : lead.value;

  static Future<void> setFridayMode(AlertMode mode) async {
    settings.value = {...settings.value, fridayKey: mode};
    await _persist();
    await _reschedule();
  }

  static Future<void> setFridayLead(int minutes) async {
    fridayLead.value = minutes;
    await _save((p) => p.setInt(_fridayLeadKey, minutes));
    await _reschedule();
  }

  /// The last computed prayer times, so a setting changed in the settings
  /// screen can take effect at once instead of waiting for the next load.
  static Map<AlertPrayer, DateTime> lastTimes = const {};

  /// And the day after, so a setting changed now reaches both.
  static Map<AlertPrayer, DateTime> tomorrow = const {};

  /// The days after tomorrow, up to [daysAhead] in all, so the adhan keeps
  /// coming for days when the app is not opened. Nothing in the background
  /// renews the alerts; opening the app does.
  static List<Map<AlertPrayer, DateTime>> later = const [];

  /// Last night's Isha while it is still to come — after midnight, in the
  /// summers of high latitudes where Isha falls past 12.
  static DateTime? lateIsha;

  /// The calendar day [lastTimes] belongs to (the chosen city's day, when
  /// there is one). Each alert's id is fixed by its day.
  static DateTime? firstDay;

  /// Days of alerts laid down at a time, today included. iPhone keeps only
  /// the 64 soonest notifications of an app (prayers, dhikr and reminders
  /// together), so it gets fewer; ten a day fit a week easily on Android.
  static int get daysAhead =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS ? 4 : 7;

  /// Set at startup. Kept as a hook rather than an import so this file stays
  /// unaware of the notification plumbing.
  static Future<void> Function(
    Map<AlertPrayer, DateTime>,
    Map<AlertPrayer, DateTime>,
  )?
  onChanged;

  /// Lays the alerts down again after a change.
  ///
  /// Never throws. Every setter runs through here, so a schedule that cannot
  /// be written — a channel the system refuses, a sound that has gone missing
  /// — used to abort the setter that called it and leave the change half
  /// applied. Turning the alerts off did the first half, threw on the way to
  /// the second, and left them on: the button then said "turn off" for ever
  /// and did nothing more, because every press failed at the same step.
  static Future<void> _reschedule() async {
    if (lastTimes.isEmpty) return;
    try {
      await onChanged?.call(lastTimes, tomorrow);
    } catch (_) {
      // The setting stands. The schedule is rebuilt at the next launch and
      // on every prayer-times load.
    }
  }

  static String keyFor(AlertPrayer prayer, AlertWhen when) =>
      '${prayer.id}_${when.id}';

  static AlertMode modeFor(AlertPrayer prayer, AlertWhen when) =>
      settings.value[keyFor(prayer, when)] ?? AlertMode.off;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      lead.value = prefs.getInt(_leadKey) ?? 15;
      fridayLead.value = prefs.getInt(_fridayLeadKey) ?? 60;
      // An id from an earlier catalogue (the voices that were withdrawn for
      // want of a licence) falls back to the default rather than to silence.
      final stored = prefs.getString(_adhanKey);
      adhan.value = Adhans.known(stored) ? stored! : Adhans.defaultId;
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
    AlertPrayer prayer,
    AlertWhen when,
    AlertMode mode,
  ) async {
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
  /// Silences every alert, and remembers what it silenced.
  ///
  /// Muting used to be one-way: the sound flags were overwritten with false
  /// and what had been on was gone, so there was nothing to switch back to
  /// and the switch did nothing in the other direction. What was on is kept
  /// aside first, and [restoreSound] puts it back exactly.
  static Future<void> muteEverything() async {
    // Only on the way in, and only from a state that had sound: muting twice
    // must not overwrite the memory with an already-silent one.
    if (anySound) {
      await _save(
        (prefs) => prefs.setString(
          _beforeMuteKey,
          jsonEncode({
            for (final e in settings.value.entries) e.key: e.value.encode(),
          }),
        ),
      );
    }

    settings.value = {
      for (final entry in settings.value.entries)
        entry.key: entry.value.withSound(false),
    };
    await _persist();
    await _reschedule();
  }

  /// Puts the sound back the way it was before the silence.
  ///
  /// With nothing remembered — a reader who silenced the alerts before this
  /// existed, or who never had a sound on — the adhan goes back on the call
  /// to prayer itself and nothing else. Doing nothing at all is the one
  /// answer that must not happen: a switch that moves and changes nothing is
  /// a switch nobody can trust.
  static Future<void> restoreSound() async {
    Map<String, AlertMode>? before;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_beforeMuteKey);
      if (raw != null) {
        final decoded = (jsonDecode(raw) as Map).cast<String, dynamic>();
        before = {
          for (final e in decoded.entries)
            e.key: AlertMode.decode(e.value as String?),
        };
      }
    } catch (_) {
      // Fall through to the sensible default below.
    }

    settings.value =
        before ??
        {
          for (final prayer in AlertPrayer.values)
            for (final when in AlertWhen.values)
              keyFor(prayer, when): when == AlertWhen.onTime
                  ? const AlertMode(notify: true, sound: true)
                  : modeFor(prayer, when),
          fridayKey: fridayMode,
        };

    await _persist();
    await _save((prefs) => prefs.remove(_beforeMuteKey));
    await _reschedule();
  }

  static bool get anySound => settings.value.values.any((m) => m.sound);

  static bool get anyOn => settings.value.values.any((m) => !m.isOff);

  static Future<void> _persist() => _save(
    (prefs) => prefs.setString(
      _key,
      jsonEncode({
        for (final e in settings.value.entries) e.key: e.value.encode(),
      }),
    ),
  );

  static Future<void> _save(
    Future<void> Function(SharedPreferences) write,
  ) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {
      // The change still applies to this session.
    }
  }
}
