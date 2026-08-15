import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/screens/radio_screen.dart';

/// Streams move and die on the server side, which no unit test can see. What
/// it can pin: the list the app ships is well-formed, and the two stations
/// asked for by name are actually on it.
void main() {
  test('the two named stations are there: Cairo and Saudi', () {
    final places = RadioScreen.stations.map((s) => s.place).join(' ');
    expect(places, contains('القاهرة'));
    expect(places, contains('السعودية'));
  });

  test('every station has a distinct id and an https url', () {
    expect(RadioScreen.stations.map((s) => s.id).toSet().length,
        RadioScreen.stations.length);
    for (final station in RadioScreen.stations) {
      expect(Uri.parse(station.url).scheme, 'https',
          reason: '${station.name} streams over plain http');
      expect(station.name.trim(), isNotEmpty);
    }
  });
}
