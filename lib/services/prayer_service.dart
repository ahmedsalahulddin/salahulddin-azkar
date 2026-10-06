import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart' show kIsWeb, ValueNotifier;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import 'app_locale.dart';
import 'dhikr_reminder.dart';
import 'notification_service.dart';
import 'prayer_alerts.dart';
import 'prayer_settings.dart';
import 'prayer_place.dart';

/// Fallback location (Riyadh) used when GPS is unavailable or denied.
final _riyadh = Coordinates(24.7136, 46.6753);

/// Where the times were computed from, and — when it is not the reader's own
/// position — what stopped us. The card turns this into something the reader
/// can act on, so every failure has to stay distinguishable.
enum LocationStatus {
  /// A fresh fix from the device.
  fixed,

  /// The last fix we obtained, reused because a new one did not arrive.
  remembered,

  /// Location permission has not been granted.
  denied,

  /// Denied for good — the system will not show the dialog again, so only the
  /// app's settings page can grant it.
  blocked,

  /// Location is switched off on the device.
  serviceOff,

  /// Permitted, but no fix arrived (indoors, or the timeout hit).
  unavailable,

  /// A city the reader picked (PrayerPlace), not the phone's location.
  chosen,
}

extension LocationStatusLabel on LocationStatus {
  /// True when the times below actually belong to the reader.
  bool get isMine =>
      this == LocationStatus.fixed ||
      this == LocationStatus.remembered ||
      this == LocationStatus.chosen;

  /// The caption on the prayer card.
  String get label => switch (this) {
    LocationStatus.chosen => PrayerPlace.current.value?.name ?? t('loc.fixed'),
    LocationStatus.fixed => t('loc.fixed'),
    LocationStatus.remembered => t('loc.remembered'),
    _ => t('loc.default'),
  };

  /// Said once, after the reader taps the marker.
  String get explanation => switch (this) {
    LocationStatus.fixed => t('loc.exFixed'),
    LocationStatus.remembered => t('loc.exRemembered'),
    LocationStatus.denied => t('loc.exDenied'),
    LocationStatus.blocked => t('loc.exBlocked'),
    LocationStatus.serviceOff => t('loc.exServiceOff'),
    LocationStatus.unavailable => t('loc.exUnavailable'),
    LocationStatus.chosen =>
      PrayerPlace.current.value?.name ?? t('place.title'),
  };
}

class PrayerInfo {
  /// Arabic name — used internally (e.g. by [SkyClock]) to identify which
  /// prayer this is, so it stays Arabic regardless of locale.
  final String name;
  final String nameEn;
  final DateTime time;
  final bool isNext;

  const PrayerInfo({
    required this.name,
    required this.nameEn,
    required this.time,
    required this.isNext,
  });

  /// What the reader actually sees — the one to use in UI text.
  String get displayName => prayerNameIn(AppLocale.code, name, nameEn);
}

/// The six names in the app's other languages, keyed by the Arabic name the
/// rest of the code identifies a prayer by. English comes from [nameEn].
const _prayerNames = <String, Map<String, String>>{
  'fr': {
    'الفجر': 'Fajr',
    'الشروق': 'Lever du soleil',
    'الظهر': 'Dhuhr',
    'العصر': 'Asr',
    'المغرب': 'Maghrib',
    'العشاء': 'Isha',
  },
  'ur': {
    'الفجر': 'فجر',
    'الشروق': 'طلوعِ آفتاب',
    'الظهر': 'ظہر',
    'العصر': 'عصر',
    'المغرب': 'مغرب',
    'العشاء': 'عشاء',
  },
  'id': {
    'الفجر': 'Subuh',
    'الشروق': 'Terbit',
    'الظهر': 'Zuhur',
    'العصر': 'Asar',
    'المغرب': 'Magrib',
    'العشاء': 'Isya',
  },
  'ms': {
    'الفجر': 'Subuh',
    'الشروق': 'Syuruk',
    'الظهر': 'Zohor',
    'العصر': 'Asar',
    'المغرب': 'Maghrib',
    'العشاء': 'Isyak',
  },
  'hi': {
    'الفجر': 'फ़ज्र',
    'الشروق': 'सूर्योदय',
    'الظهر': 'ज़ुहर',
    'العصر': 'अस्र',
    'المغرب': 'मग़रिब',
    'العشاء': 'इशा',
  },
  'tr': {
    'الفجر': 'Sabah',
    'الشروق': 'Güneş',
    'الظهر': 'Öğle',
    'العصر': 'İkindi',
    'المغرب': 'Akşam',
    'العشاء': 'Yatsı',
  },
  'bn': {
    'الفجر': 'ফজর',
    'الشروق': 'সূর্যোদয়',
    'الظهر': 'যোহর',
    'العصر': 'আসর',
    'المغرب': 'মাগরিব',
    'العشاء': 'এশা',
  },
  'ha': {
    'الفجر': 'Asuba',
    'الشروق': 'Fitowar rana',
    'الظهر': 'Azahar',
    'العصر': "La'asar",
    'المغرب': 'Magariba',
    'العشاء': 'Isha',
  },
};

String prayerNameIn(String code, String arabic, String english) =>
    switch (code) {
      'ar' => arabic,
      'en' => english,
      _ => _prayerNames[code]?[arabic] ?? english,
    };

class PrayerData {
  final List<PrayerInfo> prayers;
  final String nextName;
  final String nextNameEn;
  final DateTime nextTime;
  final LocationStatus status;

  String get nextDisplayName =>
      prayerNameIn(AppLocale.code, nextName, nextNameEn);

  /// The method these times were actually computed with, so the reader can be
  /// told rather than left to assume.
  final PrayerMethod method;

  const PrayerData({
    required this.prayers,
    required this.nextName,
    required this.nextNameEn,
    required this.nextTime,
    required this.status,
    this.method = PrayerMethod.ummAlQura,
  });
}

class PrayerService {
  /// Bumped when the reader goes back to their own location somewhere other
  /// than the prayer card (the settings row): the card then locates them
  /// itself, asking for the permission if need be, and shows the result.
  static final locateRequests = ValueNotifier<int>(0);

  static const _latKey = 'prayer_lat';
  static const _lngKey = 'prayer_lng';

  static const _order = [
    Prayer.fajr,
    Prayer.sunrise,
    Prayer.dhuhr,
    Prayer.asr,
    Prayer.maghrib,
    Prayer.isha,
  ];

  static const _names = {
    Prayer.fajr: 'الفجر',
    Prayer.sunrise: 'الشروق',
    Prayer.dhuhr: 'الظهر',
    Prayer.asr: 'العصر',
    Prayer.maghrib: 'المغرب',
    Prayer.isha: 'العشاء',
  };

  static const _namesEn = {
    Prayer.fajr: 'Fajr',
    Prayer.sunrise: 'Sunrise',
    Prayer.dhuhr: 'Dhuhr',
    Prayer.asr: 'Asr',
    Prayer.maghrib: 'Maghrib',
    Prayer.isha: 'Isha',
  };

  /// Prayer times for today.
  ///
  /// [ask] decides whether a missing permission raises the system dialog. The
  /// card passes false on the automatic load and true when the reader taps the
  /// marker, so the app never demands the location before it has shown the
  /// reader why it wants it.
  static Future<PrayerData> load({bool ask = false}) async {
    // A city the reader picked stands in for the phone's location.
    final place = PrayerPlace.current.value;
    final (coords, status) = place != null
        ? (Coordinates(place.lat, place.lng), LocationStatus.chosen)
        : await currentCoordinates(ask: ask);

    // The authority and the Asr rule come from the reader's settings, which
    // default to whichever method is used where they are standing.
    final params = PrayerSettings.parametersFor(
      coords.latitude,
      coords.longitude,
    );

    final now = DateTime.now();
    // "Today" is the city's today: a city hours away may still be on
    // yesterday, or already on tomorrow.
    final wall = PrayerPlace.onCityClock(now);
    // Just west of the date line (Samoa, Tonga) the astronomical day the
    // library works from is the local day before, so the calendar is
    // shifted until today's Dhuhr falls on today's date.
    var shift = 0;
    PrayerTimes onDay(int offset) => PrayerTimes(
      coords,
      // Noon, so a summer-time change at midnight can't land on the wrong day.
      DateComponents.from(
        DateTime(wall.year, wall.month, wall.day + offset + shift, 12),
      ),
      params,
    );

    PrayerTimes? tryDay(int offset) {
      try {
        return onDay(offset);
      } catch (_) {
        // Near the poles some days have no such times at all.
        return null;
      }
    }

    final probe = tryDay(0);
    if (probe == null) {
      // No times here today (midnight sun, polar night): clear what an
      // earlier place left waiting, then say so on the card.
      PrayerAlerts.lastTimes = const {};
      PrayerAlerts.tomorrow = const {};
      PrayerAlerts.later = const [];
      PrayerAlerts.lateIsha = null;
      PrayerAlerts.firstDay = DateTime(wall.year, wall.month, wall.day);
      unawaited(NotificationService.schedulePrayerAlerts(const {}));
      throw StateError('no prayer times for this place today');
    }
    final noon = PrayerPlace.onCityClock(probe.dhuhr);
    shift = DateTime.utc(
      wall.year,
      wall.month,
      wall.day,
    ).difference(DateTime.utc(noon.year, noon.month, noon.day)).inDays;
    final today = shift == 0 ? probe : onDay(0);

    // Where Isha falls after midnight, last night's is still to come in the
    // small hours, and it is the next prayer — so long as it comes before
    // today's Fajr.
    final yesterdayIsha = tryDay(-1)?.isha;
    final lateIsha =
        yesterdayIsha != null &&
            yesterdayIsha.isAfter(now) &&
            yesterdayIsha.isBefore(today.fajr)
        ? yesterdayIsha
        : null;
    final next = lateIsha != null ? Prayer.isha : today.nextPrayer();

    // After Isha, nextPrayer() returns Prayer.none — roll over to tomorrow's Fajr.
    late final String nextName;
    late final String nextNameEn;
    late final DateTime nextTime;
    if (next == Prayer.none) {
      nextTime = tryDay(1)?.fajr ?? today.fajr.add(const Duration(days: 1));
      nextName = _names[Prayer.fajr]!;
      nextNameEn = _namesEn[Prayer.fajr]!;
    } else if (lateIsha != null) {
      nextTime = lateIsha;
      nextName = _names[Prayer.isha]!;
      nextNameEn = _namesEn[Prayer.isha]!;
    } else {
      nextTime = today.timeForPrayer(next)!;
      nextName = _names[next]!;
      nextNameEn = _namesEn[next]!;
    }

    final prayers = _order
        .map(
          (p) => PrayerInfo(
            name: _names[p]!,
            nameEn: _namesEn[p]!,
            time: today.timeForPrayer(p)!,
            isNext: p == next,
          ),
        )
        .toList();

    // The times move every day, so the alerts are laid down again on every
    // load rather than once at install — and remembered, so a setting changed
    // in the meantime can rebuild them without waiting for another load.
    // An Isha that is not before the next day's Fajr (the far north in
    // summer) is left out of the alerts rather than ring with the Fajr.
    Map<AlertPrayer, DateTime> alertTimes(PrayerTimes? t, PrayerTimes? next) {
      if (t == null) return const {};
      return {
        AlertPrayer.fajr: t.fajr,
        AlertPrayer.dhuhr: t.dhuhr,
        AlertPrayer.asr: t.asr,
        AlertPrayer.maghrib: t.maghrib,
        if (next == null || t.isha.isBefore(next.fajr))
          AlertPrayer.isha: t.isha,
      };
    }

    final week = [today, for (var d = 1; d <= 7; d++) tryDay(d)];
    final alerts = [
      for (var d = 0; d < 7; d++) alertTimes(week[d], week[d + 1]),
    ];
    // All set together, and the days ahead even while every alert is off,
    // so one switched on later in this session reaches them too.
    PrayerAlerts.lastTimes = alerts[0];
    PrayerAlerts.tomorrow = alerts[1];
    PrayerAlerts.later = alerts.sublist(2);
    PrayerAlerts.lateIsha = lateIsha;
    PrayerAlerts.firstDay = DateTime(wall.year, wall.month, wall.day + shift);
    // Laid down even with every alert off: that clears what an earlier
    // session left waiting.
    unawaited(
      NotificationService.schedulePrayerAlerts(
        PrayerAlerts.lastTimes,
        PrayerAlerts.tomorrow,
      ),
    );
    // Reminders tied to the prayers move with them, so they are laid down
    // again here rather than once when the setting was made.
    if (DhikrReminder.enabled.value &&
        DhikrReminder.rhythm.value == DhikrRhythm.beforePrayer) {
      unawaited(DhikrReminder.reschedule());
    }

    return PrayerData(
      prayers: prayers,
      nextName: nextName,
      nextNameEn: nextNameEn,
      nextTime: nextTime,
      status: status,
      method: PrayerSettings.effective(coords.latitude, coords.longitude),
    );
  }

  /// The reader's coordinates — a fresh fix if one is available, the last
  /// remembered one otherwise, Riyadh failing that. Shared by [load] and
  /// anything else that needs a location without its own prayer-time math
  /// (the Qibla screen).
  static Future<(Coordinates, LocationStatus)> currentCoordinates({
    bool ask = false,
  }) async {
    var coords = _riyadh;
    var status = LocationStatus.denied;

    try {
      final fix = await _locate(ask: ask);
      status = fix.status;
      final pos = fix.position;
      if (pos != null) {
        // A fix a few streets from the last one is the same place: keeping
        // the old point keeps the times — and the alerts laid for them —
        // from shifting a minute back and forth between reloads.
        final last = await _lastKnown();
        if (last != null &&
            Geolocator.distanceBetween(
                  last.latitude,
                  last.longitude,
                  pos.latitude,
                  pos.longitude,
                ) <
                3000) {
          coords = last;
        } else {
          coords = Coordinates(pos.latitude, pos.longitude);
          await _remember(pos);
        }
      } else {
        // No fix now, but a place we reached before beats defaulting to a city
        // the reader may be nowhere near.
        final last = await _lastKnown();
        if (last != null) {
          coords = last;
          status = LocationStatus.remembered;
        }
      }
    } catch (_) {
      // Geolocator is unavailable (tests, web without permission). Riyadh it is.
    }

    return (coords, status);
  }

  static Future<({Position? position, LocationStatus status})> _locate({
    required bool ask,
  }) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (position: null, status: LocationStatus.serviceOff);
    }

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied && ask) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      return (position: null, status: LocationStatus.denied);
    }
    if (perm == LocationPermission.deniedForever) {
      return (position: null, status: LocationStatus.blocked);
    }

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      return (position: pos, status: LocationStatus.fixed);
    } catch (_) {
      // Permission is there; the fix simply did not arrive.
      return (position: null, status: LocationStatus.unavailable);
    }
  }

  /// Opens the page that can undo whatever blocked us, so a rejected permission
  /// is two taps from fixed rather than a dead end.
  static Future<void> openSettingsFor(LocationStatus status) async {
    if (kIsWeb) return;
    if (status == LocationStatus.serviceOff) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }

  static Future<void> _remember(Position pos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, pos.latitude);
    await prefs.setDouble(_lngKey, pos.longitude);
  }

  static Future<Coordinates?> _lastKnown() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_latKey);
    final lng = prefs.getDouble(_lngKey);
    if (lat == null || lng == null) return null;
    return Coordinates(lat, lng);
  }

  /// A prayer time as the clock reads it where the prayer is: the chosen
  /// city's clock when there is one, the phone's otherwise.
  static String formatPrayerTime(DateTime dt) =>
      formatTime(PrayerPlace.onCityClock(dt));

  static String formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final pm = dt.hour >= 12;
    // Arabic and Urdu read ص/م; every other language here writes AM/PM.
    final mark = switch (AppLocale.code) {
      'ar' => pm ? 'م' : 'ص',
      'ur' => pm ? 'شام' : 'صبح',
      _ => pm ? 'PM' : 'AM',
    };
    return '$h:$m $mark';
  }

  static String formatCountdown(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
