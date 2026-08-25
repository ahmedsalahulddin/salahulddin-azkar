import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/constants/theme.dart';
import 'package:salahulddin_azkar/services/notification_service.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// The reminders were scheduled correctly, counted correctly, and delivered
/// three hours late — because nothing ever told the timezone database which
/// zone the reader was standing in, and until told it answers Greenwich.
///
/// Every symptom pointed elsewhere: the permission was granted, the schedule
/// was in the system, the channels were loud enough. Only the hour was wrong,
/// and an hour is the one thing a reminder is.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(tzdata.initializeTimeZones);

  group('the clock the reminders are written against', () {
    test('an hour named in the settings is that hour on the reader\'s phone',
        () async {
      await NotificationService.syncTimeZone();

      // The reader is shown "٣:٥٥ص". This is the only assertion that matters:
      // the moment the app hands to Android is the moment the reader read.
      const wall = (hour: 3, minute: 55);
      final asScheduled = tz.TZDateTime(
          tz.local, 2026, 8, 26, wall.hour, wall.minute);
      final asRead = DateTime(2026, 8, 26, wall.hour, wall.minute);

      expect(asScheduled.millisecondsSinceEpoch, asRead.millisecondsSinceEpoch,
          reason: 'left on UTC this is out by the whole offset — three hours '
              'in the Kingdom, and the reminder simply never comes when the '
              'app said it would');
    });

    test('it does not silently settle for Greenwich when nobody is there',
        () async {
      // No platform channel answers in a test, so this exercises the fallback
      // rather than the named zone — which is the path that has to hold,
      // because it is the one that runs when the phone will not give a name.
      await NotificationService.syncTimeZone();

      expect(tz.local.currentTimeZone.offset,
          DateTime.now().timeZoneOffset.inMilliseconds,
          reason: 'the fallback must carry the device offset, not zero');
    });

    test('the reader can see which clock it chose', () async {
      await NotificationService.syncTimeZone();
      expect(NotificationService.zoneName, contains('UTC'));
      expect(NotificationService.zoneName.trim(), isNotEmpty);
    });
  });

  testWidgets('a message the app answers with can actually be read',
      (tester) async {
    // It came back as an empty black box. Material fills an unset content
    // colour with onInverseSurface, which in a dark theme is itself dark, so
    // every one of these said nothing at all.
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('سيصلك تنبيه بعد دقيقة'))),
            child: const Text('say'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('say'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));

    final message = tester.widget<Text>(find.text('سيصلك تنبيه بعد دقيقة'));
    final style = message.style ??
        DefaultTextStyle.of(tester.element(find.text('سيصلك تنبيه بعد دقيقة')))
            .style;
    final colour = style.color!;
    final background = tester
            .widget<SnackBar>(find.byType(SnackBar))
            .backgroundColor ??
        AppTheme.darkTheme.snackBarTheme.backgroundColor!;

    expect(colour.computeLuminance(), greaterThan(background.computeLuminance()),
        reason: 'the words have to be lighter than the box they sit in');
    expect(colour.computeLuminance() - background.computeLuminance(),
        greaterThan(0.3),
        reason: 'and lighter by enough to read at a glance');
  });
}
