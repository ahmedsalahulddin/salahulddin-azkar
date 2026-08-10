import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/prayer_service.dart';

class PrayerTimesCard extends StatefulWidget {
  const PrayerTimesCard({super.key});

  @override
  State<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<PrayerTimesCard> {
  PrayerData? _data;
  bool _failed = false;
  Duration _remaining = Duration.zero;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await PrayerService.load();
      if (!mounted) return;
      setState(() {
        _data = data;
        _failed = false;
        _remaining = data.nextTime.difference(DateTime.now());
      });
      _startTicker();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final data = _data;
      if (data == null) return;
      final left = data.nextTime.difference(DateTime.now());
      // Prayer time arrived — recompute so the next prayer rolls over.
      if (left.isNegative) {
        _ticker?.cancel();
        _load();
        return;
      }
      if (mounted) setState(() => _remaining = left);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyLight, AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: _failed
          ? _message('تعذّر حساب أوقات الصلاة')
          : _data == null
              ? _message('جاري حساب أوقات الصلاة…')
              : _content(_data!),
    );
  }

  Widget _message(String text) => SizedBox(
        height: 150,
        child: Center(
          child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ),
      );

  /// Just the time left and the six prayers, with an arrow over the next one.
  /// The prayer's name and clock time already sit in the row below, so naming
  /// them again above only cost height.
  Widget _content(PrayerData data) {
    return Column(
      children: [
        // Countdown and location share a row — the location is a one-off
        // caption and did not earn a line of its own.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Text(
                PrayerService.formatCountdown(_remaining),
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  color: AppColors.textGold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                data.isLocationBased ? '📍 حسب موقعك' : '📍 الرياض',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 11),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: data.prayers.map(_prayerColumn).toList(),
          ),
        ),
      ],
    );
  }

  Widget _prayerColumn(PrayerInfo p) {
    final color = p.isNext ? AppColors.gold : AppColors.textMuted;
    return Column(
      children: [
        // Marks the prayer being counted down to.
        Icon(
          Icons.arrow_drop_down,
          size: 16,
          color: p.isNext ? AppColors.gold : Colors.transparent,
        ),
        Text(p.name,
            style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: p.isNext ? FontWeight.bold : FontWeight.normal)),
        const SizedBox(height: 2),
        Text(PrayerService.formatTime(p.time),
            style: TextStyle(
                color: p.isNext ? AppColors.textGold : AppColors.textMuted,
                fontSize: 11)),
      ],
    );
  }
}
