import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salahulddin_azkar/widgets/mushaf_frames.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The frames are drawn, not bundled, which means the geometry has to hold on
/// its own at every size the page can be — and above all it must never stray
/// into the text it surrounds.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  const page = Size(380, 600);

  /// Non-transparent pixels the painter puts down, optionally counting only
  /// those inside [within].
  Future<int> ink(MushafFrame frame, Size size, {Rect? within}) async {
    final recorder = ui.PictureRecorder();
    MushafFramePainter(frame: frame, color: const Color(0xFF000000))
        .paint(Canvas(recorder), size);
    final image = await recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);

    var count = 0;
    for (var y = 0; y < size.height.toInt(); y++) {
      for (var x = 0; x < size.width.toInt(); x++) {
        if (within != null && !within.contains(Offset(x + 0.5, y + 0.5))) {
          continue;
        }
        final alpha = data!.getUint8((y * size.width.toInt() + x) * 4 + 3);
        if (alpha > 8) count++;
      }
    }
    return count;
  }

  group('the catalogue', () {
    test('ids and labels are unique — the picker has to tell them apart', () {
      expect(MushafFrame.values.map((f) => f.id).toSet().length,
          MushafFrame.values.length);
      expect(MushafFrame.values.map((f) => f.label).toSet().length,
          MushafFrame.values.length);
    });

    test('an id survives the round trip, and a strange one does not throw', () {
      for (final f in MushafFrame.values) {
        expect(MushafFrame.byId(f.id), f);
      }
      // A setting written by a newer build must not stop an older one opening
      // the Mushaf.
      expect(MushafFrame.byId('a-frame-from-the-future'), MushafFrame.keyline);
      expect(MushafFrame.byId(null), MushafFrame.keyline);
    });

    test('a heavier ornament reserves more of the page', () {
      expect(MushafFrame.none.insetFor(page),
          lessThan(MushafFrame.keyline.insetFor(page)));
      expect(MushafFrame.keyline.insetFor(page),
          lessThan(MushafFrame.stars.insetFor(page)));
    });
  });

  group('drawing', () {
    test('every frame but "none" actually puts something down', () async {
      expect(await ink(MushafFrame.none, page), 0);
      for (final frame in MushafFrame.values) {
        if (frame == MushafFrame.none) continue;
        expect(await ink(frame, page), greaterThan(400),
            reason: '${frame.id} drew almost nothing');
      }
    });

    test('the ornament never strays into the text', () async {
      // This is the one that matters: the page is inset by exactly this much,
      // so any ink inside the box would be sitting on top of an ayah.
      for (final frame in MushafFrame.values) {
        final inset = frame.insetFor(page);
        final content = Rect.fromLTWH(inset, inset, page.width - inset * 2,
            page.height - inset * 2);
        expect(await ink(frame, page, within: content), 0,
            reason: '${frame.id} drew inside the text area');
      }
    });

    test('it survives sizes far outside the page it was drawn for', () async {
      for (final frame in MushafFrame.values) {
        // A picker swatch, and a tablet.
        for (final size in [const Size(48, 66), const Size(1000, 1400)]) {
          expect(await ink(frame, size), isNonNegative);
        }
        // Degenerate boxes must not throw — a page can be laid out at zero
        // while an animation settles.
        expect(
            () => MushafFramePainter(frame: frame, color: const Color(0xFF000000))
                .paint(Canvas(ui.PictureRecorder()), Size.zero),
            returnsNormally);
      }
    });

    test('repainting is asked for only when something changed', () {
      const black = Color(0xFF000000);
      final painter = MushafFramePainter(frame: MushafFrame.stars, color: black);
      expect(
          painter.shouldRepaint(
              MushafFramePainter(frame: MushafFrame.stars, color: black)),
          isFalse);
      expect(
          painter.shouldRepaint(
              MushafFramePainter(frame: MushafFrame.chain, color: black)),
          isTrue);
      // The whole point of drawing them: the theme colour flows through.
      expect(
          painter.shouldRepaint(MushafFramePainter(
              frame: MushafFrame.stars, color: const Color(0xFFB8860B))),
          isTrue);
    });
  });

  group('remembering the choice', () {
    test('a chosen frame comes back on the next run', () async {
      await MushafFrames.choose(MushafFrame.arabesque);
      expect(MushafFrames.current.value, MushafFrame.arabesque);

      // Fresh start, same stored preference.
      MushafFrames.current.value = MushafFrame.none;
      await MushafFrames.load();
      expect(MushafFrames.current.value, MushafFrame.arabesque);
    });

    test('a reader who never chose gets the plain keyline', () async {
      MushafFrames.current.value = MushafFrame.stars;
      await MushafFrames.load();
      expect(MushafFrames.current.value, MushafFrame.keyline);
    });
  });

  testWidgets('the box insets its child by exactly what the frame needs',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      // Centred, or the route's tight constraints would stretch the box to
      // the whole test surface and the measurement would mean nothing.
      home: Center(
        child: SizedBox(
          width: 380,
          height: 600,
          child: MushafFrameBox(
            frame: MushafFrame.stars,
            color: Color(0xFFB8860B),
            child: SizedBox.expand(key: ValueKey('page')),
          ),
        ),
      ),
    ));

    final inset = MushafFrame.stars.insetFor(const Size(380, 600));
    final child = tester.getSize(find.byKey(const ValueKey('page')));
    expect(child.width, closeTo(380 - inset * 2, 0.5));
    expect(child.height, closeTo(600 - inset * 2, 0.5));
  });
}
