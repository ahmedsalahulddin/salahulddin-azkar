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
/// Night is the shallow dip below the horizon, running from Maghrib on the
/// left back round to Fajr on the right. Together the two make one closed
/// circuit of twenty-four hours, and the sun or the moon is somewhere on it at
/// every moment — which is the whole idea.
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

  static const height = 292.0;

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
                // Clear of the arch's shoulders and the horizon above.
                padding: const EdgeInsets.fromLTRB(38, 196, 38, 14),
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
    _paintArchEdge(canvas, arch);
  }

  // ---- the arch ----------------------------------------------------------

  /// A multifoil arch, built the way one is actually built: a run of circular
  /// lobes strung along a guide, each meeting its neighbour at a cusp, on
  /// straight jambs. The guide is an ellipse rather than a circle so the crown
  /// stays broad — a narrow crown would crowd the sun off its own path — with
  /// a sharp rise at the very top to give the ogee its point.
  Path _archPath(Size size) {
    final cx = size.width / 2;
    final spring = size.height * 0.62;
    final rx = size.width / 2 - 5;
    final ry = (spring - 12) / 1.17;
    const lobes = 8;

    Offset guide(double s) {
      final theta = math.pi * s;
      // Narrow and strong, so the boost lands on the top cusp alone and
      // leaves it a point rather than lifting the whole crown.
      final peak = 1 + 0.17 * math.pow(math.sin(theta), 26).toDouble();
      return Offset(
          cx + rx * math.cos(theta), spring - ry * math.sin(theta) * peak);
    }

    final path = Path()
      ..moveTo(cx + rx, size.height)
      ..lineTo(cx + rx, spring);
    for (var i = 0; i < lobes; i++) {
      final from = guide(i / lobes);
      final to = guide((i + 1) / lobes);
      // Bulging outward, so the meeting points read as cusps rather than as a
      // rippled curve.
      path.arcToPoint(to,
          radius: Radius.circular((to - from).distance * 0.6),
          clockwise: false);
    }
    path.lineTo(cx - rx, size.height);
    return path..close();
  }

  void _paintArchEdge(Canvas canvas, Path arch) {
    canvas.drawPath(
        arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = _gold.withValues(alpha: 0.85));
    canvas.drawPath(
        arch,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = _goldLight);
  }

  /// The eight-point star tessellation behind the arch — the ground the
  /// architecture sits against.
  void _paintTiles(Canvas canvas, Size size, Path arch) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = _gold.withValues(alpha: 0.30);
    final faint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = _gold.withValues(alpha: 0.16);

    const cell = 46.0;
    for (var y = -cell; y < size.height + cell; y += cell) {
      for (var x = -cell; x < size.width + cell; x += cell) {
        final c = Offset(x + cell / 2, y + cell / 2);
        _star(canvas, c, cell * 0.42, 8, line, innerRatio: 0.52);
        _star(canvas, c, cell * 0.42, 8, faint,
            innerRatio: 0.52, rotation: math.pi / 8);
        // The octagon between four stars, which is what closes the pattern.
        _star(canvas, Offset(c.dx + cell / 2, c.dy + cell / 2), cell * 0.19, 4,
            faint, innerRatio: 0.86, rotation: math.pi / 4);
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
    final horizon = size.height * 0.545;
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

    // The daylight arc, drawn solid; the night, dotted.
    final day = Path();
    for (var i = 0; i <= 90; i++) {
      final p = at(i / 90);
      i == 0 ? day.moveTo(p.dx, p.dy) : day.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        day,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = _gold.withValues(alpha: 0.75));

    for (var i = 0; i < 46; i++) {
      final p = at(1 + i / 46);
      canvas.drawCircle(
          p, 0.9, Paint()..color = _gold.withValues(alpha: 0.42));
    }

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

  void _paintGlow(Canvas canvas, Offset centre, bool daylight) {
    final colour = daylight ? const Color(0xFFFFD98A) : const Color(0xFFF3E4B8);
    for (var i = 5; i >= 1; i--) {
      canvas.drawCircle(centre, i * 8.5,
          Paint()..color = colour.withValues(alpha: 0.055 * (6 - i)));
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
