import 'dart:async';
import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/prayer_service.dart';
import 'rotating_verse.dart';
import 'sky_arch.dart';

class PrayerTimesCard extends StatefulWidget {
  const PrayerTimesCard({super.key});

  @override
  State<PrayerTimesCard> createState() => _PrayerTimesCardState();
}

class _PrayerTimesCardState extends State<PrayerTimesCard> {
  PrayerData? _data;
  bool _failed = false;
  bool _locating = false;
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

  Future<void> _load({bool ask = false}) async {
    try {
      final data = await PrayerService.load(ask: ask);
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

  /// Tapping the marker is the reader asking for their own location, so this is
  /// where we may raise the permission dialog — and where we say what happened
  /// either way, rather than quietly showing Riyadh again.
  Future<void> _locateMe() async {
    if (_locating) return;
    setState(() => _locating = true);
    await _load(ask: true);
    if (!mounted) return;
    setState(() => _locating = false);

    final status = _data?.status;
    if (status == null) return;

    if (status == LocationStatus.blocked ||
        status == LocationStatus.serviceOff) {
      await _offerSettings(status);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(status.explanation, textAlign: TextAlign.right),
        backgroundColor: AppColors.blackCard,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// A blocked permission cannot be re-asked from inside the app — only the
  /// system settings page can undo it, so we offer to open it directly.
  Future<void> _offerSettings(LocationStatus status) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          title: const Text('تحديد الموقع',
              style: TextStyle(color: AppColors.gold, fontSize: 17)),
          content: Text(
            '${status.explanation}.\nافتح الإعدادات لتفعيله، ثم ارجع واضغط على علامة الموقع.',
            style: const TextStyle(
                color: AppColors.textSecondary, fontSize: 14, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('لاحقاً',
                  style: TextStyle(color: AppColors.textMuted)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('فتح الإعدادات',
                  style: TextStyle(color: AppColors.gold)),
            ),
          ],
        ),
      ),
    );
    if (go == true) await PrayerService.openSettingsFor(status);
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
    final data = _data;

    return Column(
      children: [
        // The sky above, the reckoning below.
        if (data != null)
          SkyArch(
            data: data,
            now: DateTime.now(),
            child: Column(
              children: [
                const Expanded(child: RotatingVerse()),
                const SizedBox(height: 8),
                _timesColumn(data),
              ],
            ),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.symmetric(vertical: 10),
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
              : data == null
                  ? _message('جاري حساب أوقات الصلاة…')
                  : _content(data),
        ),
      ],
    );
  }

  Widget _message(String text) => SizedBox(
        height: 150,
        child: Center(
          child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 14)),
        ),
      );

  /// The reckoning under the arch: which prayer is next and when, the time
  /// left, and where the times were computed for. The times themselves are up
  /// inside the arch now.
  Widget _content(PrayerData data) {
    return Column(
      children: [
        // Which prayer is being counted down to, and when it falls.
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الصلاة القادمة',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(data.nextName,
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 21,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('الموعد',
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(PrayerService.formatTime(data.nextTime),
                      style: const TextStyle(
                          color: AppColors.textGold,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
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
            const SizedBox(width: 8),
            Flexible(child: _locationChip(data.status)),
          ],
        ),
        const SizedBox(height: 10),

      ],
    );
  }

  /// The five prayers, one to a line, inside the arch.
  ///
  /// Sunrise is not among them: it is not a prayer, and it is already marked on
  /// the sky above where it means something — the end of Fajr's time and the
  /// point the sun crosses the horizon.
  Widget _timesColumn(PrayerData data) {
    final prayers =
        data.prayers.where((p) => p.name != 'الشروق').toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final prayer in prayers) _timeRow(prayer),
      ],
    );
  }

  Widget _timeRow(PrayerInfo prayer) {
    final next = prayer.isNext;
    return Container(
      margin: const EdgeInsets.only(bottom: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: next ? AppColors.goldMuted : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: next ? AppColors.gold : Colors.transparent, width: 1),
      ),
      child: Row(
        children: [
          if (next)
            const Padding(
              padding: EdgeInsets.only(left: 5),
              child: Icon(Icons.play_arrow, size: 11, color: AppColors.gold),
            ),
          Text(prayer.name,
              style: TextStyle(
                  color: next ? AppColors.gold : AppColors.textSecondary,
                  fontSize: 12.5,
                  fontWeight: next ? FontWeight.bold : FontWeight.normal)),
          const Spacer(),
          Text(PrayerService.formatTime(prayer.time),
              style: TextStyle(
                  color: next ? AppColors.textGold : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: next ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  /// The marker is a button: pressing it goes and finds the reader. While the
  /// times are still Riyadh's it says so and invites the tap, because a reader
  /// in Cairo has no other clue that the times below are not theirs.
  Widget _locationChip(LocationStatus status) {
    final mine = status.isMine;
    final tint = mine ? AppColors.textMuted : AppColors.gold;

    return GestureDetector(
      onTap: _locateMe,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: mine ? Colors.transparent : AppColors.goldMuted,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: mine ? Colors.transparent : AppColors.goldBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_locating)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 1.6, color: AppColors.gold),
              )
            else
              Icon(mine ? Icons.my_location : Icons.location_searching,
                  size: 13, color: tint),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                _locating
                    ? 'جاري تحديد موقعك…'
                    : mine
                        ? status.label
                        : '${status.label} · حدّد موقعك',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: _locating ? AppColors.textGold : tint, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }


}
