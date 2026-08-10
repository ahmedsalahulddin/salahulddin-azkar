import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';

/// Fallback location (Riyadh) used when GPS is unavailable or denied.
final _riyadh = Coordinates(24.7136, 46.6753);

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
  final bool isLocationBased;

  const PrayerData({
    required this.prayers,
    required this.nextName,
    required this.nextTime,
    required this.isLocationBased,
  });
}

class PrayerService {
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

  static Future<PrayerData> load() async {
    var coords = _riyadh;
    var locationBased = false;

    try {
      final pos = await _locate();
      if (pos != null) {
        coords = Coordinates(pos.latitude, pos.longitude);
        locationBased = true;
      }
    } catch (_) {
      // Fall back to Riyadh silently.
    }

    final params = CalculationMethod.umm_al_qura.getParameters()
      ..madhab = Madhab.shafi;

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
      isLocationBased: locationBased,
    );
  }

  static Future<Position?> _locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return null;
    }

    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 8),
      ),
    );
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
