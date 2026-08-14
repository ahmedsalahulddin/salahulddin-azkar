import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../services/prayer_service.dart';

/// The prayer day drawn as the sky it actually is.
///
/// The curve is the sun's own path. Sunrise sits at the right end of the
/// horizon, sunset at the left, and the top of the arc is solar noon — which
/// is not a decorative choice: Dhuhr *is* the moment the sun crosses the
/// meridian, so it lands at the apex on its own, without being placed there.
/// Asr falls where the afternoon really is, a little past three quarters.
///
/// The two night prayers sit just past the horizon on the same line — Isha a
/// little below the left end, Fajr a little below the right — and the line
/// stops shortly after each of them. The hours nobody is waiting on are not
/// drawn: closing the loop underneath turned the sky into a ring.
class SkyArch extends StatelessWidget {
  final PrayerData data;
  final DateTime now;

  /// Drawn inside the arch, under the horizon.
  final Widget? child;

  const SkyArch({
    super.key,
    required this.data,
    required this.now,
    this.child,
  });

  /// Tall enough to hold the prayer times inside the arch rather than under
  /// it. The crown keeps its size whatever this is — see [_archPath] — so the
  /// extra height all goes to the jambs.
  static const height = 438.0;

  /// Where the crown stops and the jambs begin, for a given width and height.
  static double springOf(Size size) =>
      math.min(size.height * 0.62, size.width * 0.55);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: SkyArchPainter(data: data, now: now),
        child: child == null
            ? null
            : Padding(
                // Inside the jambs, and below the horizon the sky is drawn on.
                padding: const EdgeInsets.fromLTRB(54, 208, 54, 14),
                child: child,
              ),
      ),
    );
  }
}

/// Where a moment sits on the twenty-four hour circuit.
///
/// 0 is sunrise, 1 is sunset, and 1 to 2 runs through the night back to
/// sunrise. Kept out of the painter so it can be tested without a canvas.
class SkyClock {
  SkyClock(this.data);

  final PrayerData data;

  DateTime _at(String name) =>
      data.prayers.firstWhere((p) => p.name == name).time;

  DateTime get fajr => _at('الفجر');
  DateTime get sunrise => _at('الشروق');
  DateTime get maghrib => _at('المغرب');
  DateTime get isha => _at('العشاء');

  /// The position of [moment] on the circuit.
  double fractionFor(DateTime moment) {
    final day = maghrib.difference(sunrise).inSeconds;
    if (day <= 0) return 0;

    if (!moment.isBefore(sunrise) && !moment.isAfter(maghrib)) {
      return moment.difference(sunrise).inSeconds / day;
    }

    // Night. Its two halves belong to different calendar days, so the one that
    // has not happened yet is borrowed from twenty-four hours away.
    if (moment.isAfter(maghrib)) {
      final night = sunrise.add(const Duration(days: 1)).difference(maghrib);
      return 1 + moment.difference(maghrib).inSeconds / night.inSeconds;
    }
    final previous = maghrib.subtract(const Duration(days: 1));
    final night = sunrise.difference(previous);
    return 1 + moment.difference(previous).inSeconds / night.inSeconds;
  }

  /// Whether [moment] falls in daylight, which decides whether the traveller
  /// on the path is drawn as a sun or as a crescent.
  bool isDaylight(DateTime moment) => fractionFor(moment) <= 1;
}

class SkyArchPainter extends CustomPainter {
  SkyArchPainter({required this.data, required this.now});

  final PrayerData data;
  final DateTime now;

  static const _gold = AppColors.gold;
  static const _goldLight = AppColors.goldLight;
  static const _sky = Color(0xFF0B1020);

  @override
  void paint(Canvas canvas, Size size) {
    final arch = _archPath(size);

    _paintTiles(canvas, size, arch);
    canvas.save();
    canvas.clipPath(arch);
    _paintNight(canvas, size);
    _paintSkyPath(canvas, size);
    canvas.restore();
    _paintArchEdge(canvas, size, arch);
  }

  // ---- the arch ----------------------------------------------------------

  /// A mihrab arch: straight jambs, two lobes rising on each side, and a point
  /// at the crown.
  ///
  /// It is swept rather than assembled. A radius that swells with |sin 4θ| puts
  /// four lobes around the arch and leaves a cusp wherever the swell returns to
  /// zero — including at the very top, which is then lifted into the crown's
  /// point by a spike narrow enough to touch nothing else. Cusps come out sharp
  /// because they are where two smooth lobes meet at an angle, which is how the
  /// real thing is built.
  Path _archPath(Size size, {double inset = 0}) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    /// How far the lobes swell, and how far the crown rises past them.
    const swell = 0.16;
    const crown = 0.32;

    // The lobes bulge past the guide, so the guide has to sit in far enough
    // that the widest of them still clears the edge — otherwise the shoulders
    // are cut off by the canvas and the arch reads as a plain dome.
    final margin = 16.0 + inset;
    // Tied to the width, not the height: making the arch taller should lengthen
    // its jambs, not blow up its crown.
    final spring = math.min(h * 0.62, w * 0.55) - inset * 0.3;
    final rx = (cx - margin) / (1 + swell);
    final ry = (spring - (h * 0.03 + inset)) / (1 + crown);

    Offset at(double theta) {
      final lobe = 1 + swell * math.sin(4 * theta).abs();
      // A tent, not a bell. Its sides are straight and meet at an angle, which
      // is what makes the crown a point; anything smooth peaks in a dome no
      // matter how narrow it is made.
      const reach = 0.26;
      final near = 1 - math.min(1.0, math.cos(theta).abs() / reach);
      final point = 1 + crown * near;
      return Offset(
        cx + rx * lobe * math.cos(theta),
        spring - ry * lobe * math.sin(theta) * point,
      );
    }

    final path = Path()
      ..moveTo(cx + rx, h)
      ..lineTo(cx + rx, spring);
    const steps = 240;
    for (var i = 1; i <= steps; i++) {
      final p = at(math.pi * i / steps);
      path.lineTo(p.dx, p.dy);
    }
    path.lineTo(cx - rx, h);
    return path..close();
  }

  /// The gold band, and the thin line that runs inside it — a single stroke
  /// reads as a cheap outline, and the drawing this copies has both.
  void _paintArchEdge(Canvas canvas, Size size, Path arch) {
    canvas.drawPath(
        arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeJoin = StrokeJoin.round
          ..color = _gold);
    canvas.drawPath(
        arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round
          ..color = _goldLight);
    canvas.drawPath(
        _archPath(size, inset: 13),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _gold.withValues(alpha: 0.75));
  }

  /// The eight-point star tessellation behind the arch — the ground the
  /// architecture sits against.
  void _paintTiles(Canvas canvas, Size size, Path arch) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final strap = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = _gold.withValues(alpha: 0.62);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _gold.withValues(alpha: 0.42);
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9
      ..color = _gold.withValues(alpha: 0.26);

    // Fine and close-set. The panel behind a mihrab is a dense field, not a
    // handful of large stars with gaps between them.
    const cell = 28.0;
    for (var y = -cell; y < size.height + cell; y += cell) {
      for (var x = -cell; x < size.width + cell; x += cell) {
        final c = Offset(x + cell / 2, y + cell / 2);
        // The eight-point star, doubled at half a turn — the two together are
        // what a pierced gold panel actually looks like.
        _star(canvas, c, cell * 0.46, 8, strap, innerRatio: 0.55);
        _star(canvas, c, cell * 0.46, 8, line,
            innerRatio: 0.55, rotation: math.pi / 8);
        // A rosette in the middle of each star, the way the ground is filled.
        _star(canvas, c, cell * 0.17, 8, faint, innerRatio: 0.42);
        canvas.drawCircle(c, cell * 0.07, faint);
        // The octagon between four stars, which is what closes the pattern.
        _star(canvas, Offset(c.dx + cell / 2, c.dy + cell / 2), cell * 0.22, 4,
            line, innerRatio: 0.86, rotation: math.pi / 4);
        _star(canvas, Offset(c.dx + cell / 2, c.dy + cell / 2), cell * 0.13, 8,
            faint, innerRatio: 0.5);
      }
    }
    canvas.restore();
  }

  void _star(Canvas canvas, Offset centre, double r, int points, Paint paint,
      {double innerRatio = 0.45, double rotation = 0}) {
    final path = Path();
    for (var i = 0; i < points * 2; i++) {
      final angle = rotation + i * math.pi / points;
      final radius = i.isEven ? r : r * innerRatio;
      final p = Offset(centre.dx + radius * math.cos(angle),
          centre.dy + radius * math.sin(angle));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  // ---- inside the arch ---------------------------------------------------

  void _paintNight(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = _sky);

    // A fixed scatter — stars that wandered between frames would be worse than
    // no stars at all.
    final random = math.Random(7);
    for (var i = 0; i < 46; i++) {
      final p = Offset(
          random.nextDouble() * size.width, random.nextDouble() * size.height);
      final r = 0.5 + random.nextDouble() * 1.1;
      canvas.drawCircle(
          p,
          r,
          Paint()
            ..color = Colors.white
                .withValues(alpha: 0.18 + random.nextDouble() * 0.42));
    }
  }

  void _paintSkyPath(Canvas canvas, Size size) {
    final clock = SkyClock(data);
    final cx = size.width / 2;
    // The sky belongs to the crown, so it is measured from the springing
    // rather than from the bottom of a box whose height now varies.
    final horizon = SkyArch.springOf(size) * 0.86;
    final radius = math.min(size.width * 0.335, horizon - 56);
    // Deep enough that Fajr and Isha clear the two horizon prayers they sit
    // beside; any shallower and their names collide.
    const dip = 42.0;

    Offset at(double f) {
      final wrapped = f % 2;
      if (wrapped <= 1) {
        final theta = math.pi * wrapped;
        return Offset(
            cx + radius * math.cos(theta), horizon - radius * math.sin(theta));
      }
      // Night: a shallow dip below the horizon, left end back round to right.
      final p = wrapped - 1;
      final theta = math.pi * p;
      return Offset(
          cx - radius * math.cos(theta), horizon + dip * math.sin(theta));
    }

    // One open line, from a little before Fajr round to a little past Isha.
    //
    // The path is not closed at the bottom: the hours between Isha and Fajr
    // are the ones nobody is waiting on, and drawing them shut turned the sky
    // into a ring. Both ends simply run off past their prayer.
    final from = clock.fractionFor(clock.fajr) - 0.10;
    final to = 2 + clock.fractionFor(clock.isha) + 0.07;

    final line = Path();
    const steps = 150;
    for (var i = 0; i <= steps; i++) {
      final p = at(from + (to - from) * i / steps);
      i == 0 ? line.moveTo(p.dx, p.dy) : line.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..color = _gold.withValues(alpha: 0.8));

    // Where the sun or moon is now, with its glow laid down first.
    final fraction = clock.fractionFor(now);
    final here = at(fraction);
    final daylight = fraction <= 1;
    _paintGlow(canvas, here, daylight);

    for (final prayer in data.prayers) {
      final where = at(clock.fractionFor(prayer.time));
      final marked = prayer.isNext;
      canvas.drawCircle(
          where,
          marked ? 4.6 : 3.0,
          Paint()..color = marked ? _goldLight : _gold.withValues(alpha: 0.9));
      if (marked) {
        canvas.drawCircle(
            where,
            8.5,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = _goldLight.withValues(alpha: 0.65));
      }
      _label(canvas, prayer.name, where, cx, horizon, marked);

    }

    daylight ? _paintSun(canvas, here) : _paintMoon(canvas, here);
  }

  /// Kept tight. A wide halo washed over the two names beside it, and a prayer
  /// time that cannot be read is worse than one that does not glow.
  void _paintGlow(Canvas canvas, Offset centre, bool daylight) {
    final colour = daylight ? const Color(0xFFFFD98A) : const Color(0xFFF3E4B8);
    for (var i = 4; i >= 1; i--) {
      canvas.drawCircle(centre, i * 5.5,
          Paint()..color = colour.withValues(alpha: 0.05 * (5 - i)));
    }
  }

  void _paintSun(Canvas canvas, Offset centre) {
    const r = 8.5;
    canvas.drawCircle(centre, r, Paint()..color = const Color(0xFFFFE9A8));
    final ray = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFD98A);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawLine(
        centre + Offset(math.cos(a), math.sin(a)) * (r + 3.5),
        centre + Offset(math.cos(a), math.sin(a)) * (r + 7.5),
        ray,
      );
    }
  }

  void _paintMoon(Canvas canvas, Offset centre) {
    const r = 9.0;
    final disc = Path()
      ..addOval(Rect.fromCircle(center: centre, radius: r));
    final bite = Path()
      ..addOval(Rect.fromCircle(
          center: centre + const Offset(4.6, -2.4), radius: r * 0.95));
    canvas.drawPath(
      Path.combine(PathOperation.difference, disc, bite),
      Paint()..color = const Color(0xFFF6E7BC),
    );
  }

  /// Names sit inside the curve, pushed towards its centre.
  ///
  /// Outward would run them into the arch's shoulders, where there is least
  /// room; inward is also where a printed prayer dial puts them.
  void _label(Canvas canvas, String name, Offset at, double cx, double horizon,
      bool marked) {
    final painter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: marked ? _goldLight : Colors.white.withValues(alpha: 0.72),
          fontSize: marked ? 12.5 : 11.5,
          fontWeight: marked ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    final outward = at - Offset(cx, horizon);
    final length = outward.distance == 0 ? 1.0 : outward.distance;
    final unit = outward / length;
    // Below the horizon the inward direction points up into the arc, which
    // would stack Fajr on top of sunrise; those two get pushed down instead.
    final anchor = at.dy > horizon + 1
        ? at + Offset(-unit.dx * 14, 13)
        : at - unit * 17;

    painter.paint(
      canvas,
      Offset(anchor.dx - painter.width / 2, anchor.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(SkyArchPainter old) =>
      old.now != now || old.data != data;
}
