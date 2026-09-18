import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/strings.dart';
import '../services/section_config.dart';

/// Ornamental borders for a Mushaf page.
///
/// Every one of these is drawn here in code rather than bundled as a picture,
/// for two reasons that both matter. An illumination found on the web is some
/// artist's work and cannot be shipped without their licence. And a picture is
/// stuck in the colour it was painted, whereas a drawn border takes the app's
/// colour as an argument and follows it wherever the theme goes.
///
/// The vocabulary — interlace, arabesque, eight-point stars, the double rule of
/// a printed Mushaf — is centuries old and belongs to everyone. These are new
/// renderings of it.
enum MushafFrame {
  none('none'),
  keyline('keyline'),
  madinah('madinah'),
  chain('chain'),
  interlace('interlace'),
  arabesque('arabesque'),
  stars('stars'),
  rosette('rosette'),
  filigree('filigree'),
  illuminated('illuminated');

  const MushafFrame(this.id);

  final String id;

  /// Shown in the picker.
  String get label => switch (this) {
    MushafFrame.none => t('mushaf.frameNone'),
    MushafFrame.keyline => t('mushaf.frameKeyline'),
    MushafFrame.madinah => t('mushaf.frameMadinah'),
    MushafFrame.chain => t('mushaf.frameChain'),
    MushafFrame.interlace => t('mushaf.frameInterlace'),
    MushafFrame.arabesque => t('mushaf.frameArabesque'),
    MushafFrame.stars => t('mushaf.frameStars'),
    MushafFrame.rosette => t('mushaf.frameRosette'),
    MushafFrame.filigree => t('mushaf.frameFiligree'),
    MushafFrame.illuminated => t('mushaf.frameIlluminated'),
  };

  /// What a reader who has never chosen gets, and what an unreadable setting
  /// falls back to.
  static const fallback = illuminated;

  /// Unknown ids fall back rather than throwing — a setting written by a newer
  /// build must not stop an older one from opening the Mushaf.
  static MushafFrame byId(String? id) =>
      values.firstWhere((f) => f.id == id, orElse: () => fallback);

  /// The key this frame answers to in app_sections, so the dashboard can show,
  /// hide and order the frames exactly as it does the shelves.
  String get sectionKey => 'frame_$id';

  /// The frames on offer, hidden ones dropped and the rest in the dashboard's
  /// order. Fails open like everything else that reads the remote config: an
  /// unreachable project leaves every frame on the list.
  static List<MushafFrame> get available {
    final shown =
        [
          for (var i = 0; i < values.length; i++)
            if (SectionConfig.isVisible(values[i].sectionKey)) (values[i], i),
        ]..sort(
          (a, b) => SectionConfig.orderOf(
            a.$1.sectionKey,
            a.$2,
          ).compareTo(SectionConfig.orderOf(b.$1.sectionKey, b.$2)),
        );
    // Never an empty picker: a page has to have some border, even none.
    return shown.isEmpty ? [none, keyline] : [for (final (f, _) in shown) f];
  }

  /// How far the page text must stay clear of the edge, in design units. The
  /// heavier the ornament, the more room it needs.
  double get _inset => switch (this) {
    MushafFrame.none => 2,
    MushafFrame.keyline => 11,
    MushafFrame.madinah => 26,
    MushafFrame.chain => 33,
    MushafFrame.interlace => 33,
    MushafFrame.arabesque => 34,
    MushafFrame.stars => 34,
    MushafFrame.rosette => 33,
    MushafFrame.filigree => 46,
    MushafFrame.illuminated => 50,
  };

  /// The ornament is drawn at a size that suits a phone page, then scaled, so
  /// the same painter serves both the page and a small preview swatch.
  double scaleFor(Size size) => (size.shortestSide / 380).clamp(0.34, 1.5);

  double insetFor(Size size) => _inset * scaleFor(size);
}

/// The reader's chosen frame, remembered between runs.
class MushafFrames {
  static const _key = '@noor_mushaf_frame';

  /// Every visible page listens, so a choice applies to all of them at once
  /// rather than only the one on screen.
  static final current = ValueNotifier<MushafFrame>(MushafFrame.fallback);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      current.value = MushafFrame.byId(prefs.getString(_key));
    } catch (_) {
      // Keep the default; a frame is not worth failing a launch over.
    }
    reconcile();
  }

  /// Moves a reader off a frame that has since been hidden.
  ///
  /// Their choice is respected until it stops being on offer; then they get
  /// the first frame that is, rather than a page with an ornament nobody else
  /// can see. Called on launch and whenever the dashboard's answer arrives.
  static void reconcile() {
    final available = MushafFrame.available;
    if (available.contains(current.value)) return;
    choose(available.first);
  }

  static Future<void> choose(MushafFrame frame) async {
    current.value = frame;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, frame.id);
    } catch (_) {
      // The choice still applies to this session.
    }
  }
}

/// Draws [frame] around [child], insetting the child far enough to clear it.
class MushafFrameBox extends StatelessWidget {
  final MushafFrame frame;
  final Color color;
  final Widget child;

  const MushafFrameBox({
    super.key,
    required this.frame,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final scale = frame.scaleFor(size);
        final inset = frame.insetFor(size);

        // The ornament is painted wider than the page and hangs off both
        // sides, so only its top and bottom courses are in view. A page of the
        // Mushaf needs every millimetre of width it can get; side bands would
        // take that width from the ayahs, which is the one place it cannot
        // come from. The parent clips the overhang.
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: -inset,
              right: -inset,
              top: 0,
              bottom: 0,
              child: IgnorePointer(
                child: CustomPaint(
                  painter: MushafFramePainter(
                    frame: frame,
                    color: color,
                    scale: scale,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: inset),
              child: child,
            ),
          ],
        );
      },
    );
  }
}

class MushafFramePainter extends CustomPainter {
  MushafFramePainter({required this.frame, required this.color, this.scale});

  final MushafFrame frame;
  final Color color;

  /// Set when the canvas is deliberately wider than the page, so the ornament
  /// keeps the size the page asked for instead of growing with the overhang.
  final double? scale;

  @override
  void paint(Canvas canvas, Size size) {
    if (frame == MushafFrame.none) return;
    final s = scale ?? frame.scaleFor(size);

    switch (frame) {
      case MushafFrame.none:
        return;
      case MushafFrame.keyline:
        _rule(canvas, size, 4 * s, 2.0 * s, color);
        _rule(canvas, size, 9 * s, 0.9 * s, _soft);
      case MushafFrame.madinah:
        _madinah(canvas, size, s);
      case MushafFrame.chain:
        _banded(canvas, size, s, _chainStrip, corner: _diamondCorner);
      case MushafFrame.interlace:
        _banded(canvas, size, s, _braidStrip, corner: _squareCorner);
      case MushafFrame.arabesque:
        _banded(canvas, size, s, _vineStrip, corner: _rosetteCorner);
      case MushafFrame.stars:
        _banded(canvas, size, s, _starStrip, corner: _squareCorner);
      case MushafFrame.rosette:
        _banded(canvas, size, s, _petalStrip, corner: _rosetteCorner);
      case MushafFrame.filigree:
        _banded(
          canvas,
          size,
          s,
          _filigreeStrip,
          corner: _scrollCorner,
          thickness: 34,
        );
      case MushafFrame.illuminated:
        _banded(
          canvas,
          size,
          s,
          _scrollStrip,
          corner: _rosetteCorner,
          thickness: 38,
        );
        _cartouche(canvas, size, s);
    }
  }

  Color get _soft => color.withValues(alpha: 0.55);
  Color get _faint => color.withValues(alpha: 0.28);

  /// The second colour classical illumination sets against the gold — the
  /// violet in the jewels. Taken by rotating the theme's own hue rather than
  /// fixed, so it still belongs whatever colour the page is wearing.
  Color get _jewel {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withHue((hsl.hue + 205) % 360)
        .withSaturation((hsl.saturation * 0.9).clamp(0.25, 1.0))
        .withLightness((hsl.lightness * 0.85).clamp(0.2, 0.7))
        .toColor();
  }

  Paint _stroke(double width, Color c) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..color = c;

  Paint _fill(Color c) => Paint()..color = c;

  // ---- shared scaffolding ------------------------------------------------

  void _rule(Canvas canvas, Size size, double inset, double width, Color c) {
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - inset * 2,
      size.height - inset * 2,
    );
    if (rect.width <= 0 || rect.height <= 0) return;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(4 * width)),
      _stroke(width, c),
    );
  }

  /// Runs [draw] once per side, with the canvas turned so the strip is always
  /// drawn left-to-right with +y pointing into the page. One motif, four edges.
  void _forEachSide(
    Canvas canvas,
    Size size,
    double inset,
    void Function(double length) draw,
  ) {
    final w = size.width - inset * 2;
    final h = size.height - inset * 2;
    if (w <= 0 || h <= 0) return;

    final corners = <(Offset, double, double)>[
      (Offset(inset, inset), 0, w),
      (Offset(size.width - inset, inset), math.pi / 2, h),
      (Offset(size.width - inset, size.height - inset), math.pi, w),
      (Offset(inset, size.height - inset), -math.pi / 2, h),
    ];

    for (final (origin, angle, length) in corners) {
      canvas.save();
      canvas.translate(origin.dx, origin.dy);
      canvas.rotate(angle);
      draw(length);
      canvas.restore();
    }
  }

  /// A band frame: an outer rule, the repeating motif, an inner rule, and a
  /// medallion at each corner to close the seam where the four bands meet —
  /// which is exactly what the illuminators did.
  void _banded(
    Canvas canvas,
    Size size,
    double s,
    void Function(Canvas, double length, double s, double thickness) strip, {
    required void Function(Canvas, Offset, double s) corner,
    double thickness = 23,
  }) {
    const outer = 4.0;
    final inner = outer + thickness;

    _rule(canvas, size, outer * s, 1.8 * s, color);
    _rule(canvas, size, inner * s, 1.3 * s, _soft);
    _rule(canvas, size, (inner + 4) * s, 0.7 * s, _faint);

    _forEachSide(canvas, size, outer * s, (length) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, length, thickness * s));
      strip(canvas, length, s, thickness * s);
      canvas.restore();
    });

    final o = outer * s;
    for (final c in [
      Offset(o, o),
      Offset(size.width - o, o),
      Offset(size.width - o, size.height - o),
      Offset(o, size.height - o),
    ]) {
      corner(canvas, c, s);
    }
  }

  /// Divides [length] into whole repeats so the motif never ends mid-figure.
  (int, double) _repeats(double length, double ideal) {
    final n = math.max(1, (length / ideal).round());
    return (n, length / n);
  }

  void _star(
    Canvas canvas,
    Offset centre,
    double r,
    int points,
    Paint paint, {
    double innerRatio = 0.45,
    double rotation = 0,
  }) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final angle = rotation + i * math.pi / points;
      final radius = i.isEven ? r : r * innerRatio;
      final p = Offset(
        centre.dx + radius * math.cos(angle),
        centre.dy + radius * math.sin(angle),
      );
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  /// The printed Mushaf's own restraint: a heavy rule, two light ones, and the
  /// ornament kept to the corners and the middle of each side.
  void _madinah(Canvas canvas, Size size, double s) {
    _rule(canvas, size, 4 * s, 3.2 * s, color);
    _rule(canvas, size, 12 * s, 1.2 * s, _soft);
    _rule(canvas, size, 16 * s, 0.8 * s, _faint);

    final o = 4.0 * s;
    for (final c in [
      Offset(o, o),
      Offset(size.width - o, o),
      Offset(size.width - o, size.height - o),
      Offset(o, size.height - o),
    ]) {
      _rosetteCorner(canvas, c, s * 1.4);
    }

    // A single cartouche at the middle of each side, the way a printed page
    // marks its axis.
    _forEachSide(canvas, size, o, (length) {
      final centre = Offset(length / 2, 0);
      _star(canvas, centre, 7.5 * s, 6, _fill(_soft), innerRatio: 0.4);
      _star(
        canvas,
        centre,
        7.5 * s,
        6,
        _stroke(1.1 * s, color),
        innerRatio: 0.4,
      );
    });
  }

  /// The densest of the set: a scalloped outer row, a row of palmettes, and a
  /// keyline holding them in — the layered look of a gilded title page.
  void _filigreeStrip(Canvas canvas, double length, double s, double t) {
    final (n, p) = _repeats(length, t * 0.62);

    // Outer row of scallops, each hung with a bead.
    final scallops = Path();
    for (var i = 0; i < n; i++) {
      scallops.addArc(Rect.fromLTWH(i * p, -p * 0.28, p, p * 0.56), 0, math.pi);
    }
    canvas.drawPath(scallops, _stroke(1.1 * s, _soft));
    for (var i = 0; i < n; i++) {
      canvas.drawCircle(
        Offset((i + 0.5) * p, p * 0.34),
        1.4 * s,
        _fill(_faint),
      );
    }

    // The palmette row: a lily flanked by two curls, repeated.
    final top = t * 0.34;
    final base = t * 0.9;
    final petal = _stroke(1.4 * s, color);
    for (var i = 0; i < n; i++) {
      final cx = (i + 0.5) * p;
      final w = p * 0.24;

      final lily = Path()
        ..moveTo(cx, base)
        ..quadraticBezierTo(cx + w, (top + base) / 2, cx, top)
        ..quadraticBezierTo(cx - w, (top + base) / 2, cx, base);
      canvas.drawPath(lily, petal);
      canvas.drawCircle(
        Offset(cx, top + (base - top) * 0.42),
        1.6 * s,
        _fill(color),
      );

      // Curls falling away on either side.
      for (final dir in [-1.0, 1.0]) {
        final curl = Path()
          ..moveTo(cx + dir * w * 1.1, base * 0.94)
          ..cubicTo(
            cx + dir * p * 0.34,
            base * 0.86,
            cx + dir * p * 0.42,
            (top + base) / 2,
            cx + dir * p * 0.30,
            top * 1.25,
          );
        canvas.drawPath(curl, _stroke(1.0 * s, _soft));
      }
      canvas.drawCircle(Offset(i * p, base * 0.9), 1.5 * s, _fill(_soft));
    }

    canvas.drawLine(
      Offset(0, base * 1.03),
      Offset(length, base * 1.03),
      _stroke(0.8 * s, _faint),
    );
  }

  /// Facing C-scrolls with a jewel at every joint — the running ornament of an
  /// illuminated Mushaf border.
  void _scrollStrip(Canvas canvas, double length, double s, double t) {
    final (n, p) = _repeats(length, t * 0.86);
    final spine = t * 0.52;

    // The rails the scrollwork runs between.
    canvas.drawLine(
      Offset(0, t * 0.1),
      Offset(length, t * 0.1),
      _stroke(1.0 * s, _soft),
    );
    canvas.drawLine(
      Offset(0, t * 0.93),
      Offset(length, t * 0.93),
      _stroke(1.3 * s, color),
    );

    final vine = _stroke(1.5 * s, color);
    final fine = _stroke(0.9 * s, _soft);

    for (var i = 0; i < n; i++) {
      final x0 = i * p;
      final cx = x0 + p / 2;

      // Two scrolls curling away from the centre of each unit.
      for (final dir in [-1.0, 1.0]) {
        final scroll = Path()
          ..moveTo(cx, t * 0.16)
          ..cubicTo(
            cx + dir * p * 0.34,
            t * 0.18,
            cx + dir * p * 0.46,
            spine * 1.15,
            cx + dir * p * 0.16,
            t * 0.82,
          )
          ..cubicTo(
            cx + dir * p * 0.06,
            t * 0.9,
            cx + dir * p * 0.2,
            t * 0.92,
            cx + dir * p * 0.3,
            t * 0.84,
          );
        canvas.drawPath(scroll, vine);

        // The inner curl that fills the eye of the scroll.
        final eye = Path()
          ..moveTo(cx + dir * p * 0.12, t * 0.36)
          ..quadraticBezierTo(
            cx + dir * p * 0.3,
            spine,
            cx + dir * p * 0.12,
            t * 0.68,
          );
        canvas.drawPath(eye, fine);
      }

      // A bud on the axis of the unit, and the jewel at the joint between
      // units — the violet accent of the original.
      canvas.drawCircle(Offset(cx, t * 0.3), 2.2 * s, _fill(_soft));
      _star(
        canvas,
        Offset(x0, spine),
        4.6 * s,
        4,
        _fill(_jewel),
        innerRatio: 0.42,
      );
      _star(
        canvas,
        Offset(x0, spine),
        4.6 * s,
        4,
        _stroke(0.8 * s, color),
        innerRatio: 0.42,
      );
    }
  }

  /// The little tablet at the foot of an illuminated page, where the page
  /// number is written. The frame leaves the number itself to the page.
  void _cartouche(Canvas canvas, Size size, double s) {
    final w = 46.0 * s;
    final h = 15.0 * s;
    final centre = Offset(size.width / 2, size.height - 21 * s);
    final box = RRect.fromRectAndRadius(
      Rect.fromCenter(center: centre, width: w, height: h),
      Radius.circular(h / 2),
    );
    canvas.drawRRect(box, Paint()..color = const Color(0xFFF7F1E1));
    canvas.drawRRect(box, _stroke(1.2 * s, color));
    for (final dir in [-1.0, 1.0]) {
      _star(
        canvas,
        centre + Offset(dir * (w / 2 + 5 * s), 0),
        3.4 * s,
        4,
        _fill(_jewel),
        innerRatio: 0.4,
      );
    }
  }

  // ---- corner medallions -------------------------------------------------

  /// Two facing spirals, the way a gilded corner resolves its scrollwork.
  void _scrollCorner(Canvas canvas, Offset c, double s) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    _star(canvas, Offset.zero, 9.0 * s, 8, _fill(_soft), innerRatio: 0.4);
    _star(
      canvas,
      Offset.zero,
      9.0 * s,
      8,
      _stroke(1.0 * s, color),
      innerRatio: 0.4,
    );
    for (var k = 0; k < 4; k++) {
      canvas.save();
      canvas.rotate(k * math.pi / 2);
      final spiral = Path()..moveTo(6.0 * s, 0);
      for (var a = 0.0; a < math.pi * 1.6; a += 0.25) {
        final r = (6.0 + a * 2.6) * s;
        spiral.lineTo(r * math.cos(a), r * math.sin(a));
      }
      canvas.drawPath(spiral, _stroke(0.9 * s, _soft));
      canvas.restore();
    }
    canvas.drawCircle(Offset.zero, 2.6 * s, _fill(color));
    canvas.restore();
  }

  void _diamondCorner(Canvas canvas, Offset c, double s) {
    final r = 9.5 * s;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..lineTo(c.dx + r, c.dy)
      ..lineTo(c.dx, c.dy + r)
      ..lineTo(c.dx - r, c.dy)
      ..close();
    canvas.drawPath(path, _fill(color));
  }

  void _squareCorner(Canvas canvas, Offset c, double s) {
    final r = 8.0 * s;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(math.pi / 4);
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2),
      _fill(_soft),
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: r * 2, height: r * 2),
      _stroke(0.9 * s, color),
    );
    canvas.restore();
  }

  void _rosetteCorner(Canvas canvas, Offset c, double s) {
    _star(canvas, c, 11.0 * s, 8, _fill(_soft), innerRatio: 0.42);
    _star(canvas, c, 11.0 * s, 8, _stroke(1.1 * s, color), innerRatio: 0.42);
    canvas.drawCircle(c, 3.0 * s, _fill(color));
  }

  // ---- the motifs --------------------------------------------------------

  /// A chain of diamonds threaded on a line — the strapwork border.
  void _chainStrip(Canvas canvas, double length, double s, double t) {
    final y = t / 2;
    final (n, p) = _repeats(length, t * 1.5);
    final line = _stroke(0.8 * s, _faint);

    canvas.drawLine(Offset(0, y), Offset(length, y), line);

    final outline = _stroke(1.5 * s, color);
    for (var i = 0; i < n; i++) {
      final cx = (i + 0.5) * p;
      final d = p * 0.34;
      final v = t * 0.36;
      final path = Path()
        ..moveTo(cx, y - v)
        ..lineTo(cx + d, y)
        ..lineTo(cx, y + v)
        ..lineTo(cx - d, y)
        ..close();
      canvas.drawPath(path, outline);
      canvas.drawCircle(Offset(i * p, y), 2.6 * s, _fill(_soft));
    }
  }

  /// Two waves running against each other — a woven braid.
  void _braidStrip(Canvas canvas, double length, double s, double t) {
    final top = t * 0.22;
    final bottom = t * 0.78;
    final (n, p) = _repeats(length, t * 1.25);

    final up = Path()..moveTo(0, bottom);
    final down = Path()..moveTo(0, top);
    for (var i = 0; i < n; i++) {
      final x0 = i * p;
      final x1 = x0 + p;
      final bulge = p * 0.55;
      // Each repeat swaps the strands over, so they read as woven rather than
      // as two parallel waves.
      final (aFrom, aTo) = i.isEven ? (bottom, top) : (top, bottom);
      up.cubicTo(x0 + bulge, aFrom, x1 - bulge, aTo, x1, aTo);
      down.cubicTo(x0 + bulge, aTo, x1 - bulge, aFrom, x1, aFrom);
    }

    canvas.drawPath(up, _stroke(2.0 * s, color));
    canvas.drawPath(down, _stroke(2.0 * s, _soft));

    for (var i = 0; i <= n; i++) {
      canvas.drawCircle(Offset(i * p, t / 2), 2.4 * s, _fill(color));
    }
  }

  /// A scrolling vine with a bud at every crest.
  void _vineStrip(Canvas canvas, double length, double s, double t) {
    final mid = t / 2;
    final (n, p) = _repeats(length, t * 1.9);

    final vine = Path()..moveTo(0, mid);
    for (var i = 0; i < n; i++) {
      final x0 = i * p;
      final peak = i.isEven ? t * 0.2 : t * 0.8;
      vine.quadraticBezierTo(x0 + p / 2, peak + (peak - mid), x0 + p, mid);
    }
    canvas.drawPath(vine, _stroke(2.0 * s, color));

    for (var i = 0; i < n; i++) {
      final cx = (i + 0.5) * p;
      final cy = i.isEven ? t * 0.26 : t * 0.74;
      canvas.drawCircle(Offset(cx, cy), 3.6 * s, _fill(_soft));
      canvas.drawCircle(Offset(cx, cy), 3.6 * s, _stroke(1.0 * s, color));
    }
    canvas.drawLine(
      Offset(0, mid),
      Offset(length, mid),
      _stroke(0.5 * s, _faint),
    );
  }

  /// Eight-point stars — the khatim — set between small links.
  void _starStrip(Canvas canvas, double length, double s, double t) {
    final y = t / 2;
    final (n, p) = _repeats(length, t * 1.7);

    canvas.drawLine(Offset(0, y), Offset(length, y), _stroke(0.7 * s, _faint));
    for (var i = 0; i < n; i++) {
      final cx = (i + 0.5) * p;
      _star(canvas, Offset(cx, y), t * 0.42, 8, _fill(_soft), innerRatio: 0.46);
      _star(
        canvas,
        Offset(cx, y),
        t * 0.42,
        8,
        _stroke(1.3 * s, color),
        innerRatio: 0.46,
      );
      final link = Offset(i * p, y);
      canvas.drawRect(
        Rect.fromCenter(center: link, width: 4.6 * s, height: 4.6 * s),
        _fill(color),
      );
    }
  }

  /// A row of shamsas — small sunbursts, the mark of an illuminated page.
  void _petalStrip(Canvas canvas, double length, double s, double t) {
    final y = t / 2;
    final (n, p) = _repeats(length, t * 1.35);

    for (var i = 0; i < n; i++) {
      final cx = (i + 0.5) * p;
      final r = math.min(t * 0.38, p * 0.36);
      for (var k = 0; k < 8; k++) {
        final a = k * math.pi / 4;
        canvas.drawCircle(
          Offset(cx + r * 0.62 * math.cos(a), y + r * 0.62 * math.sin(a)),
          r * 0.34,
          _fill(_faint),
        );
      }
      canvas.drawCircle(Offset(cx, y), r * 0.4, _fill(color));
      canvas.drawCircle(Offset(cx, y), r, _stroke(0.7 * s, _soft));
    }
  }

  /// The border is decoration and must never take a tap.
  ///
  /// This is not a default worth trusting: [CustomPainter.hitTest] returns
  /// null, and RenderCustomPaint reads that as *yes*. A painter laid over the
  /// page therefore swallows every tap on it — which is exactly what stopped
  /// ayahs being selected, and with them the bookmark, tafsir, copy and share
  /// buttons that only light up once one is.
  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(MushafFramePainter old) =>
      old.frame != frame || old.color != color || old.scale != scale;
}
