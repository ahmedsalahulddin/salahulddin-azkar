import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'app_locale.dart';

/// A city the reader picked for the prayer times, instead of the phone's own
/// location: somewhere they are going, somewhere family lives, or simply
/// their own city when the phone won't share its location.
class PrayerPlace {
  final String name;
  final String region;
  final String country;
  final double lat;
  final double lng;

  /// The city's IANA zone, so its times show on its own clock.
  final String zone;

  const PrayerPlace({
    required this.name,
    required this.region,
    required this.country,
    required this.lat,
    required this.lng,
    required this.zone,
  });

  /// Region and country, for the line under the name.
  String get where => [
    if (region.isNotEmpty && region != name) region,
    if (country.isNotEmpty) country,
  ].join(AppLocale.code == 'ar' || AppLocale.code == 'ur' ? '، ' : ', ');

  Map<String, dynamic> toJson() => {
    'name': name,
    'region': region,
    'country': country,
    'lat': lat,
    'lng': lng,
    'zone': zone,
  };

  static PrayerPlace? fromJson(Map<String, dynamic> j) {
    final lat = (j['lat'] as num?)?.toDouble();
    final lng = (j['lng'] as num?)?.toDouble();
    final name = j['name'] as String?;
    if (lat == null || lng == null || name == null) return null;
    return PrayerPlace(
      name: name,
      region: j['region'] as String? ?? '',
      country: j['country'] as String? ?? '',
      lat: lat,
      lng: lng,
      zone: j['zone'] as String? ?? '',
    );
  }

  bool sameAs(PrayerPlace other) =>
      (lat - other.lat).abs() < 0.0001 && (lng - other.lng).abs() < 0.0001;

  static const _key = 'prayer_place';

  /// The chosen city, or null to follow the phone's location.
  static final current = ValueNotifier<PrayerPlace?>(null);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      current.value = raw == null
          ? null
          : fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      current.value = null;
    }
  }

  /// Picks [place], or goes back to the phone's location when null.
  static Future<void> choose(PrayerPlace? place) async {
    current.value = place;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (place == null) {
        await prefs.remove(_key);
      } else {
        await prefs.setString(_key, jsonEncode(place.toJson()));
      }
    } catch (_) {
      // Kept for this session at least.
    }
  }

  /// The chosen city's time zone, or null when there is no city (or its zone
  /// is unknown) and the phone's own clock applies.
  static tz.Location? get cityZone {
    final name = current.value?.zone;
    if (name == null || name.isEmpty) return null;
    try {
      // Loaded once. Loading again would reset the zone the notifications
      // are scheduled against.
      if (!tz.timeZoneDatabase.isInitialized) tzdata.initializeTimeZones();
      return tz.getLocation(name);
    } catch (_) {
      return null;
    }
  }

  /// [moment] on the chosen city's clock — or unchanged without a city.
  static DateTime onCityClock(DateTime moment) {
    final z = cityZone;
    return z == null ? moment : tz.TZDateTime.from(moment, z);
  }

  /// Cities matching [query], in the reader's language where the names are
  /// known in it. Throws when the search could not be made (no connection).
  static Future<List<PrayerPlace>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': q,
      'count': '20',
      'language': AppLocale.code,
      'format': 'json',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 12));
    if (res.statusCode != 200) throw Exception('search ${res.statusCode}');
    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map;
    final results = (body['results'] as List?) ?? const [];
    return [
      for (final r in results.cast<Map>())
        if (r['latitude'] is num && r['longitude'] is num)
          PrayerPlace(
            name: r['name'] as String? ?? q,
            region: r['admin1'] as String? ?? '',
            country: r['country'] as String? ?? '',
            lat: (r['latitude'] as num).toDouble(),
            lng: (r['longitude'] as num).toDouble(),
            zone: r['timezone'] as String? ?? '',
          ),
    ];
  }
}
