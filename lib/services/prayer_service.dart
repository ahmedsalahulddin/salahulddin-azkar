import 'package:adhan/adhan.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final String name;
  final DateTime time;
  final bool isNext;

  const PrayerInfo({required this.name, required this.time, required this.isNext});
}

class PrayerData {
  final List<PrayerInfo> prayers;
  final String nextName;
  final DateTime nextTime;
  final LocationStatus status;

  /// The method these times were actually computed with, so the reader can be
  /// told rather than left to assume.
  final PrayerMethod method;

  const PrayerData({
    required this.prayers,
    required this.nextName,
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

  /// Prayer times for today.
  ///
  /// [ask] decides whether a missing permission raises the system dialog. The
  /// card passes false on the automatic load and true when the reader taps the
  /// marker, so the app never demands the location before it has shown the
  /// reader why it wants it.
  static Future<PrayerData> load({bool ask = false}) async {
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

    // The authority and the Asr rule come from the reader's settings, which
    // default to whichever method is used where they are standing.
    final params = PrayerSettings.parametersFor(coords.latitude, coords.longitude);

    final today = PrayerTimes.today(coords, params);
    final next = today.nextPrayer();

    // After Isha, nextPrayer() returns Prayer.none — roll over to tomorrow's Fajr.
    late final String nextName;
    late final DateTime nextTime;
    if (next == Prayer.none) {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      nextTime = PrayerTimes(coords, DateComponents.from(tomorrow), params).fajr;
      nextName = _names[Prayer.fajr]!;
    } else {
      nextTime = today.timeForPrayer(next)!;
      nextName = _names[next]!;
    }

    final prayers = _order
        .map((p) => PrayerInfo(
              name: _names[p]!,
              time: today.timeForPrayer(p)!,
              isNext: p == next,
            ))
        .toList();

    return PrayerData(
      prayers: prayers,
      nextName: nextName,
      nextTime: nextTime,
      status: status,
      method: PrayerSettings.effective(coords.latitude, coords.longitude),
    );
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
