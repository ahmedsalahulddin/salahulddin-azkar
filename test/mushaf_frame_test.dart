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
  Future<int> ink(MushafFrame frame, Size size,
      {Rect? within, double? scale}) async {
    final recorder = ui.PictureRecorder();
    MushafFramePainter(
            frame: frame, color: const Color(0xFF000000), scale: scale)
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
      expect(MushafFrame.byId('a-frame-from-the-future'), MushafFrame.fallback);
      expect(MushafFrame.byId(null), MushafFrame.fallback);
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
      // This is the one that matters. The page keeps its full width and is
      // inset only top and bottom, on a canvas widened by that inset on each
      // side so the ornament's flanks hang off view. Any ink inside the box
      // would be sitting on top of an ayah.
      for (final frame in MushafFrame.values) {
        final inset = frame.insetFor(page);
        final widened = Size(page.width + inset * 2, page.height);
        final content =
            Rect.fromLTWH(inset, inset, page.width, page.height - inset * 2);
        expect(await ink(frame, widened, within: content, scale: frame.scaleFor(page)), 0,
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

    test('a reader who never chose gets the default border', () async {
      MushafFrames.current.value = MushafFrame.stars;
      await MushafFrames.load();
      expect(MushafFrames.current.value, MushafFrame.fallback);
      // Which is the illuminated Mushaf page, the one the app opens on.
      expect(MushafFrame.fallback, MushafFrame.illuminated);
    });
  });

  group('the border is decoration', () {
    test('it refuses every tap offered to it', () {
      // CustomPainter.hitTest returns null by default and RenderCustomPaint
      // reads null as yes, so a painter laid over the page swallows the taps
      // that select an ayah — and with them the bookmark, tafsir, copy and
      // share buttons, which only work once one is selected.
      final painter = MushafFramePainter(
          frame: MushafFrame.stars, color: const Color(0xFFB8860B));
      for (final point in [
        Offset.zero,
        const Offset(190, 300),
        const Offset(379, 599),
      ]) {
        expect(painter.hitTest(point), isFalse);
      }
    });

    testWidgets('a tap passes through it to the page underneath',
        (tester) async {
      var taps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Center(
          child: SizedBox(
            width: 380,
            height: 600,
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps++,
                  child: const SizedBox.expand(),
                ),
                // The border, laid over the whole page exactly as the Mushaf
                // lays it.
                Positioned.fill(
                  child: CustomPaint(
                    painter: MushafFramePainter(
                        frame: MushafFrame.filigree,
                        color: const Color(0xFFB8860B)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ));

      await tester.tapAt(tester.getCenter(find.byType(Stack).last));
      await tester.pump();
      expect(taps, 1, reason: 'the border swallowed the tap');
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
    // Full width kept; only the top and bottom courses take room.
    expect(child.width, closeTo(380, 0.5));
    expect(child.height, closeTo(600 - inset * 2, 0.5));
  });
}
