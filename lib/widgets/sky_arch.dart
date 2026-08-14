import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../services/prayer_service.dart';

/// The prayer day drawn as the sky it actually is: a dome on the horizon, and
/// the sun's own path arcing over it.
///
/// Sunrise sits at the right end of the horizon, sunset at the left, and the
/// top of the arc is solar noon — which is not a decorative choice: Dhuhr *is*
/// the moment the sun crosses the meridian, so it lands at the apex on its
/// own, without being placed there. The two night prayers sit just past the
/// horizon, Isha below the left end and Fajr below the right.
class SkyArch extends StatelessWidget {
  final PrayerData data;
  final DateTime now;

  const SkyArch({super.key, required this.data, required this.now});

  static const height = 236.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: SkyArchPainter(data: data, now: now)),
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

  @override
  void paint(Canvas canvas, Size size) {
    final panel = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(20));
    canvas.save();
    canvas.clipRRect(panel);

    // The sky, darkening upward the way dusk actually does.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF070B16), Color(0xFF101A33)],
        ).createShader(Offset.zero & size),
    );
    _stars(canvas, size);

    final horizon = size.height * 0.74;
    _horizon(canvas, size, horizon);
    _dome(canvas, Offset(size.width / 2, horizon));
    _skyPath(canvas, size, horizon);

    canvas.restore();
    canvas.drawRRect(
        panel,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = _gold.withValues(alpha: 0.35));
  }

  void _stars(Canvas canvas, Size size) {
    // A fixed scatter — stars that wandered between frames would be worse
    // than no stars at all.
    final random = math.Random(7);
    for (var i = 0; i < 40; i++) {
      canvas.drawCircle(
        Offset(random.nextDouble() * size.width,
            random.nextDouble() * size.height * 0.7),
        0.5 + random.nextDouble(),
        Paint()
          ..color =
              Colors.white.withValues(alpha: 0.15 + random.nextDouble() * 0.4),
      );
    }
  }

  void _horizon(Canvas canvas, Size size, double y) {
    canvas.drawLine(
        Offset(14, y),
        Offset(size.width - 14, y),
        Paint()
          ..strokeWidth = 1
          ..color = _gold.withValues(alpha: 0.4));
  }

  /// A mosque dome on the horizon: drum, onion bulb, finial and crescent.
  void _dome(Canvas canvas, Offset base) {
    final cx = base.dx;
    final ground = base.dy;

    final fill = Paint()..color = const Color(0xFF1A2138);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = _gold;

    // The drum the bulb sits on.
    final drum = Rect.fromLTRB(cx - 26, ground - 16, cx + 26, ground);
    canvas.drawRect(drum, fill);
    canvas.drawLine(drum.topLeft, drum.bottomLeft, edge);
    canvas.drawLine(drum.topRight, drum.bottomRight, edge);

    // The onion bulb: out past the drum, then a long taper into the point.
    final y0 = ground - 16;
    final bulb = Path()
      ..moveTo(cx - 26, y0)
      ..cubicTo(cx - 46, y0 - 14, cx - 40, y0 - 46, cx - 8, y0 - 66)
      ..quadraticBezierTo(cx, y0 - 72, cx + 8, y0 - 66)
      ..cubicTo(cx + 40, y0 - 46, cx + 46, y0 - 14, cx + 26, y0);
    canvas.drawPath(bulb, fill);
    canvas.drawPath(bulb, edge);

    // Finial and crescent.
    final tip = Offset(cx, y0 - 72);
    canvas.drawLine(
        tip,
        tip - const Offset(0, 9),
        Paint()
          ..strokeWidth = 1.6
          ..color = _gold);
    final c = tip - const Offset(0, 15);
    final disc = Path()..addOval(Rect.fromCircle(center: c, radius: 5.4));
    final bite = Path()
      ..addOval(
          Rect.fromCircle(center: c + const Offset(2.4, -1), radius: 4.8));
    canvas.drawPath(Path.combine(PathOperation.difference, disc, bite),
        Paint()..color = _goldLight);
  }

  void _skyPath(Canvas canvas, Size size, double horizon) {
    final clock = SkyClock(data);
    final cx = size.width / 2;
    final radius = math.min(size.width * 0.40, horizon - 26);
    final dip = math.min(20.0, size.height - horizon - 18);

    Offset at(double f) {
      final wrapped = f % 2;
      if (wrapped <= 1) {
        final theta = math.pi * wrapped;
        return Offset(
            cx + radius * math.cos(theta), horizon - radius * math.sin(theta));
      }
      final p = wrapped - 1;
      final theta = math.pi * p;
      return Offset(
          cx - radius * math.cos(theta), horizon + dip * math.sin(theta));
    }

    // Daylight solid, night dotted.
    final day = Path();
    for (var i = 0; i <= 90; i++) {
      final p = at(i / 90);
      i == 0 ? day.moveTo(p.dx, p.dy) : day.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        day,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = _gold.withValues(alpha: 0.8));
    for (var i = 0; i < 42; i++) {
      canvas.drawCircle(
          at(1 + i / 42), 0.9, Paint()..color = _gold.withValues(alpha: 0.4));
    }

    final fraction = clock.fractionFor(now);
    final here = at(fraction);
    _glow(canvas, here, fraction <= 1);

    for (final prayer in data.prayers) {
      final where = at(clock.fractionFor(prayer.time));
      final marked = prayer.isNext;
      canvas.drawCircle(
          where,
          marked ? 4.4 : 2.9,
          Paint()..color = marked ? _goldLight : _gold.withValues(alpha: 0.9));
      if (marked) {
        canvas.drawCircle(
            where,
            8,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.1
              ..color = _goldLight.withValues(alpha: 0.6));
      }
      _label(canvas, prayer.name, where, cx, horizon, marked);
    }

    fraction <= 1 ? _sun(canvas, here) : _moon(canvas, here);
  }

  void _glow(Canvas canvas, Offset centre, bool daylight) {
    final colour = daylight ? const Color(0xFFFFD98A) : const Color(0xFFF3E4B8);
    for (var i = 5; i >= 1; i--) {
      canvas.drawCircle(centre, i * 7.5,
          Paint()..color = colour.withValues(alpha: 0.05 * (6 - i)));
    }
  }

  void _sun(Canvas canvas, Offset centre) {
    const r = 7.5;
    canvas.drawCircle(centre, r, Paint()..color = const Color(0xFFFFE9A8));
    final ray = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFFFD98A);
    for (var i = 0; i < 12; i++) {
      final a = i * math.pi / 6;
      canvas.drawLine(
        centre + Offset(math.cos(a), math.sin(a)) * (r + 3),
        centre + Offset(math.cos(a), math.sin(a)) * (r + 6.5),
        ray,
      );
    }
  }

  void _moon(Canvas canvas, Offset centre) {
    const r = 8.0;
    final disc = Path()..addOval(Rect.fromCircle(center: centre, radius: r));
    final bite = Path()
      ..addOval(Rect.fromCircle(
          center: centre + const Offset(4.2, -2.2), radius: r * 0.95));
    canvas.drawPath(Path.combine(PathOperation.difference, disc, bite),
        Paint()..color = const Color(0xFFF6E7BC));
  }

  /// Day labels sit inside the curve; the two night prayers get pushed down
  /// below the horizon instead, where inward would stack them on the ends.
  void _label(Canvas canvas, String name, Offset at, double cx, double horizon,
      bool marked) {
    final painter = TextPainter(
      text: TextSpan(
        text: name,
        style: TextStyle(
          color: marked ? _goldLight : Colors.white.withValues(alpha: 0.75),
          fontSize: marked ? 12 : 11,
          fontWeight: marked ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.rtl,
    )..layout();

    final outward = at - Offset(cx, horizon);
    final length = outward.distance == 0 ? 1.0 : outward.distance;
    final unit = outward / length;
    final anchor = at.dy > horizon + 1
        ? at + Offset(-unit.dx * 12, 13)
        : at - unit * 16;

    painter.paint(canvas,
        Offset(anchor.dx - painter.width / 2, anchor.dy - painter.height / 2));
  }

  @override
  bool shouldRepaint(SkyArchPainter old) => old.now != now || old.data != data;
}
