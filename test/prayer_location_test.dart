import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:salahulddin_azkar/services/prayer_service.dart';
import 'package:salahulddin_azkar/widgets/prayer_times_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The card falls back to Riyadh whenever it cannot place the reader, and that
/// fallback is silent by nature: a reader in Cairo would see Riyadh's Maghrib
/// and have no hint anything was wrong. So the marker has to say which case it
/// is in, and pressing it has to actually go and look.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => GeolocatorPlatform.instance = _FakeGeolocator());

  // Cairo — far enough from Riyadh that the prayer times cannot coincide.
  const cairo = (lat: 30.0444, lng: 31.2357);

  group('what the status means', () {
    test('only a real fix counts as the reader\'s own location', () {
      expect(LocationStatus.fixed.isMine, isTrue);
      expect(LocationStatus.remembered.isMine, isTrue);
      for (final s in [
        LocationStatus.denied,
        LocationStatus.blocked,
        LocationStatus.serviceOff,
        LocationStatus.unavailable,
      ]) {
        expect(s.isMine, isFalse, reason: '$s is not the reader\'s location');
      }
    });

    test('every failure says Riyadh, and none of them pretends otherwise', () {
      for (final s in LocationStatus.values) {
        expect(s.label, s.isMine ? isNot('الرياض') : 'الرياض');
      }
    });

    test('each failure explains itself differently', () {
      // The point of splitting the enum is telling the reader which switch to
      // flip; identical wording would waste that.
      final said = LocationStatus.values.map((s) => s.explanation).toSet();
      expect(said.length, LocationStatus.values.length);
      expect(said.every((t) => t.trim().isNotEmpty), isTrue);
    });
  });

  group('locating the reader', () {
    test('a granted permission puts the reader on their own times', () async {
      // A device that has never had a fix: Riyadh.
      GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);
      final riyadh = await PrayerService.load();
      expect(riyadh.status, LocationStatus.serviceOff);

      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.whileInUse,
        at: cairo,
      );
      final mine = await PrayerService.load();

      expect(mine.status, LocationStatus.fixed);
      expect(mine.prayers.first.time, isNot(riyadh.prayers.first.time),
          reason: 'Cairo and Riyadh cannot share a Fajr');
    });

    test('the fix is remembered, so a later failure is not a trip to Riyadh',
        () async {
      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.always,
        at: cairo,
      );
      final fresh = await PrayerService.load();

      // Same device, no signal this time.
      GeolocatorPlatform.instance = _FakeGeolocator(
        permission: LocationPermission.always,
      );
      final again = await PrayerService.load();

      expect(again.status, LocationStatus.remembered);
      expect(again.prayers.first.time, fresh.prayers.first.time);
    });

    test('asking is what raises the dialog, not merely loading', () async {
      final quiet = _FakeGeolocator(at: cairo);
      GeolocatorPlatform.instance = quiet;
      await PrayerService.load();
      expect(quiet.asked, isFalse,
          reason: 'the automatic load must not demand the permission');
      expect(quiet.granted, isFalse);

      final asked = _FakeGeolocator(at: cairo);
      GeolocatorPlatform.instance = asked;
      final data = await PrayerService.load(ask: true);
      expect(asked.asked, isTrue);
      expect(data.status, LocationStatus.fixed);
    });

    test('each refusal is reported as itself', () async {
      Future<LocationStatus> statusWhen(_FakeGeolocator fake) async {
        GeolocatorPlatform.instance = fake;
        return (await PrayerService.load(ask: true)).status;
      }

      expect(await statusWhen(_FakeGeolocator(serviceEnabled: false)),
          LocationStatus.serviceOff);
      expect(
          await statusWhen(
              _FakeGeolocator(permission: LocationPermission.deniedForever)),
          LocationStatus.blocked);
      // Refused at the dialog.
      expect(await statusWhen(_FakeGeolocator(grantOnRequest: false)),
          LocationStatus.denied);
      // Allowed, but no fix arrives.
      expect(
          await statusWhen(
              _FakeGeolocator(permission: LocationPermission.whileInUse)),
          LocationStatus.unavailable);
    });
  });

  group('the card', () {
    Future<void> pumpCard(WidgetTester tester) async {
      // Mounted the way the home screen mounts it: the header is taller than
      // a short screen, and scrolls there rather than being squeezed.
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: PrayerTimesCard()),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('says it is showing Riyadh, and invites the tap',
        (tester) async {
      GeolocatorPlatform.instance = _FakeGeolocator(serviceEnabled: false);
      await pumpCard(tester);

      expect(find.textContaining('الرياض'), findsOneWidget);
      expect(find.textContaining('حدّد موقعك'), findsOneWidget);
      // The times themselves still rendered. Named more than once when the
      // prayer in question is also the next one, so this must not count.
      expect(find.text('الفجر'), findsWidgets);
      expect(find.text('المغرب'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('pressing the marker locates the reader', (tester) async {
      // Permission not yet granted: the tap is what raises the dialog.
      final fake = _FakeGeolocator(at: cairo);
      GeolocatorPlatform.instance = fake;
      await pumpCard(tester);
      expect(find.textContaining('حدّد موقعك'), findsOneWidget);

      await tester.tap(find.textContaining('حدّد موقعك'));
      await tester.pump(); // spinner
      await tester.pump(const Duration(milliseconds: 50)); // fix arrives
      await tester.pump(); // snack bar

      expect(fake.asked, isTrue);
      expect(find.text('حسب موقعك'), findsOneWidget);
      expect(find.textContaining('حدّد موقعك'), findsNothing);
      expect(find.text(LocationStatus.fixed.explanation), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('a refusal explains itself instead of silently staying put',
        (tester) async {
      GeolocatorPlatform.instance = _FakeGeolocator(grantOnRequest: false);
      await pumpCard(tester);

      await tester.tap(find.textContaining('حدّد موقعك'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump();

      expect(find.text(LocationStatus.denied.explanation), findsOneWidget);
      // Still offering the retry.
      expect(find.textContaining('حدّد موقعك'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('a permanently blocked permission offers the settings page',
        (tester) async {
      GeolocatorPlatform.instance =
          _FakeGeolocator(permission: LocationPermission.deniedForever);
      await pumpCard(tester);

      await tester.tap(find.textContaining('حدّد موقعك'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      // A dialog, not a snack bar — the app cannot ask again by itself.
      expect(find.text('فتح الإعدادات'), findsOneWidget);
      expect(find.textContaining(LocationStatus.blocked.explanation),
          findsOneWidget);

      await tester.tap(find.text('لاحقاً'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 4));
    });
  });
}

/// Stands in for the device. Every permission state the reader can be in is a
/// constructor argument, so the tests never need a real GPS.
class _FakeGeolocator extends GeolocatorPlatform with MockPlatformInterfaceMixin {
  _FakeGeolocator({
    this.serviceEnabled = true,
    this.permission = LocationPermission.denied,
    this.grantOnRequest = true,
    this.at,
  });

  final bool serviceEnabled;
  final bool grantOnRequest;
  final ({double lat, double lng})? at;

  LocationPermission permission;

  /// Whether the system dialog was raised, and whether it ended in a grant.
  bool asked = false;
  bool get granted =>
      permission == LocationPermission.whileInUse ||
      permission == LocationPermission.always;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async {
    asked = true;
    if (permission == LocationPermission.denied && grantOnRequest) {
      permission = LocationPermission.whileInUse;
    }
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    final here = at;
    if (here == null) {
      throw const LocationServiceDisabledException();
    }
    return Position(
      latitude: here.lat,
      longitude: here.lng,
      timestamp: DateTime(2026),
      accuracy: 50,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}
