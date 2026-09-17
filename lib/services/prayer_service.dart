import 'dart:async';

import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_locale.dart';
import 'dhikr_reminder.dart';
import 'notification_service.dart';
import 'prayer_alerts.dart';
import 'prayer_settings.dart';

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
}

extension LocationStatusLabel on LocationStatus {
  /// True when the times below actually belong to the reader.
  bool get isMine =>
      this == LocationStatus.fixed || this == LocationStatus.remembered;

  /// The caption on the prayer card.
  String get label => switch (this) {
    LocationStatus.fixed => 'حسب موقعك',
    LocationStatus.remembered => 'موقعك المحفوظ',
    _ => 'الرياض',
  };

  /// Said once, after the reader taps the marker.
  String get explanation => switch (this) {
    LocationStatus.fixed => 'تم تحديد موقعك، وحُسبت المواقيت عليه',
    LocationStatus.remembered =>
      'تعذّر تحديث الموقع الآن، والمواقيت محسوبة على آخر موقع معروف',
    LocationStatus.denied =>
      'التطبيق يحتاج إذن الموقع ليحسب المواقيت على مدينتك',
    LocationStatus.blocked =>
      'إذن الموقع مرفوض من إعدادات الجهاز، ولن يظهر السؤال مرة أخرى',
    LocationStatus.serviceOff => 'خدمة الموقع مغلقة في جهازك',
    LocationStatus.unavailable =>
      'تعذّر الوصول للموقع. جرّب قرب نافذة أو في مكان مكشوف',
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
  String get displayName => AppLocale.isEn ? nameEn : name;
}

class PrayerData {
  final List<PrayerInfo> prayers;
  final String nextName;
  final String nextNameEn;
  final DateTime nextTime;
  final LocationStatus status;

  String get nextDisplayName => AppLocale.isEn ? nextNameEn : nextName;

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
    final (coords, status) = await currentCoordinates(ask: ask);

    // The authority and the Asr rule come from the reader's settings, which
    // default to whichever method is used where they are standing.
    final params = PrayerSettings.parametersFor(
      coords.latitude,
      coords.longitude,
    );

    final today = PrayerTimes.today(coords, params);
    final next = today.nextPrayer();

    // After Isha, nextPrayer() returns Prayer.none — roll over to tomorrow's Fajr.
    late final String nextName;
    late final String nextNameEn;
    late final DateTime nextTime;
    if (next == Prayer.none) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      nextTime = PrayerTimes(
        coords,
        DateComponents.from(tomorrow),
        params,
      ).fajr;
      nextName = _names[Prayer.fajr]!;
      nextNameEn = _namesEn[Prayer.fajr]!;
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
    PrayerAlerts.lastTimes = {
      AlertPrayer.fajr: today.fajr,
      AlertPrayer.dhuhr: today.dhuhr,
      AlertPrayer.asr: today.asr,
      AlertPrayer.maghrib: today.maghrib,
      AlertPrayer.isha: today.isha,
    };
    if (PrayerAlerts.anyOn) {
      // Tomorrow's as well, so a day of not opening the app does not leave
      // the reader with nothing waiting for them.
      final ahead = PrayerTimes(
        coords,
        DateComponents.from(DateTime.now().add(const Duration(days: 1))),
        params,
      );
      PrayerAlerts.tomorrow = {
        AlertPrayer.fajr: ahead.fajr,
        AlertPrayer.dhuhr: ahead.dhuhr,
        AlertPrayer.asr: ahead.asr,
        AlertPrayer.maghrib: ahead.maghrib,
        AlertPrayer.isha: ahead.isha,
      };
      unawaited(
        NotificationService.schedulePrayerAlerts(
          PrayerAlerts.lastTimes,
          PrayerAlerts.tomorrow,
        ),
      );
    }
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
        coords = Coordinates(pos.latitude, pos.longitude);
        await _remember(pos);
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

  static String formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m ${dt.hour >= 12 ? 'م' : 'ص'}';
  }

  static String formatCountdown(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }
}
