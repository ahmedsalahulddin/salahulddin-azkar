import 'dart:async';
import 'dart:math' as math;

import 'package:adhan/adhan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';

import '../constants/theme.dart';
import '../services/prayer_service.dart';

/// Points to the Kaaba using the device's magnetometer and the reader's
/// location — the direction itself comes from [Qibla] (part of the same
/// adhan package that already computes prayer times), so no separate
/// calculation is carried here.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  double? _qiblaBearing;
  LocationStatus? _status;
  StreamSubscription<CompassEvent>? _sub;
  double? _heading;
  bool _compassTimedOut = false;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = FlutterCompass.events?.listen((event) {
      if (!mounted || event.heading == null) return;
      setState(() {
        _heading = event.heading;
        _compassTimedOut = false;
      });
    });
    // Simulators and a few Android devices report no magnetometer at all —
    // say so rather than leaving the reader staring at a dial that never
    // moves.
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _heading == null) setState(() => _compassTimedOut = true);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _load({bool ask = false}) async {
    final (coords, status) = await PrayerService.currentCoordinates(ask: ask);
    if (!mounted) return;
    setState(() {
      _qiblaBearing = Qibla(coords).direction;
      _status = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    final needsPermission =
        status == LocationStatus.denied ||
        status == LocationStatus.blocked ||
        status == LocationStatus.serviceOff;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: const Text('اتجاه القبلة'),
        ),
        body: status == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : needsPermission
            ? _permissionPrompt(status)
            : _compass(),
      ),
    );
  }

  Widget _permissionPrompt(LocationStatus status) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore_off, size: 56, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text(
              status.explanation,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: status == LocationStatus.denied
                  ? () => _load(ask: true)
                  : () => PrayerService.openSettingsFor(status),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold),
              child: Text(
                status == LocationStatus.denied
                    ? 'السماح بالموقع'
                    : 'فتح الإعدادات',
                style: const TextStyle(color: AppColors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _compass() {
    final heading = _heading;
    final qibla = _qiblaBearing;

    if (heading == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_compassTimedOut) ...[
                const CircularProgressIndicator(color: AppColors.gold),
                const SizedBox(height: 16),
                const Text(
                  'جارٍ قراءة البوصلة…',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ] else ...[
                const Icon(
                  Icons.explore_off,
                  size: 56,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                const Text(
                  'تعذّر الوصول لبوصلة الجهاز.\nقد لا يدعم جهازك هذه الميزة، '
                  'أو تحتاج لتجربتها على جهاز حقيقي بدل المحاكي.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // Angle from the top of the screen to the Kaaba, given which way the
    // device currently faces.
    final needleAngle = ((qibla ?? 0) - heading) * math.pi / 180;
    final aligned = qibla != null && _angleDiff(qibla, heading) <= 5;

    return Column(
      children: [
        const SizedBox(height: 12),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: aligned ? AppColors.emeraldMuted : AppColors.blackCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: aligned ? AppColors.emeraldLight : AppColors.goldBorder,
            ),
          ),
          child: Text(
            aligned
                ? 'أنت متّجه نحو القبلة الآن'
                : 'وجّه أعلى الجهاز نحو السهم',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: aligned ? AppColors.emeraldLight : AppColors.textSecondary,
              fontWeight: aligned ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 280,
                    height: 280,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.goldBorder, width: 2),
                    ),
                  ),
                  for (final deg in [0, 90, 180, 270])
                    Transform.rotate(
                      angle: (deg - heading) * math.pi / 180,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            const {0: 'ش', 90: 'ق', 180: 'ج', 270: 'غ'}[deg]!,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Transform.rotate(
                    angle: needleAngle,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mosque,
                          color: aligned
                              ? AppColors.emeraldLight
                              : AppColors.gold,
                          size: 30,
                        ),
                        Container(
                          width: 3,
                          height: 95,
                          decoration: BoxDecoration(
                            color: aligned
                                ? AppColors.emeraldLight
                                : AppColors.gold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 28),
          child: Text(
            qibla == null ? '' : 'القبلة: ${qibla.round()}° من الشمال',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  double _angleDiff(double a, double b) {
    final diff = (a - b).abs() % 360;
    return diff > 180 ? 360 - diff : diff;
  }
}
