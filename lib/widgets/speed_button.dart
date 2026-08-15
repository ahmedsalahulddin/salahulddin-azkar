import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../services/playback_speed.dart';

/// Picks the playback speed.
///
/// Speeds are picked from a list rather than cycled: seven steps meant up to
/// six taps to reach the one you wanted. It was written for the Mushaf and
/// now serves every player in the app, so the reader sets the pace once.
class SpeedButton extends StatelessWidget {
  /// False on the compact bars, where the circle alone has to do.
  final bool showLabel;

  const SpeedButton({super.key, this.showLabel = true});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: PlaybackSpeed.value,
      builder: (context, speed, _) {
        final changed = speed != 1.0;
        final tint = changed ? AppColors.gold : AppColors.textSecondary;
        final text = PlaybackSpeed.label(speed);

        return PopupMenuButton<double>(
          tooltip: 'سرعة التشغيل',
          color: AppColors.blackCard,
          position: PopupMenuPosition.under,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.goldBorder),
          ),
          padding: EdgeInsets.zero,
          onSelected: PlaybackSpeed.set,
          itemBuilder: (context) => [
            for (final s in PlaybackSpeed.options)
              PopupMenuItem(
                value: s,
                height: 38,
                child: Row(
                  children: [
                    if (s == speed)
                      const Icon(Icons.check, color: AppColors.gold, size: 15)
                    else
                      const SizedBox(width: 15),
                    const SizedBox(width: 8),
                    Text(
                      s == 1.0 ? 'الطبيعية' : '${PlaybackSpeed.label(s)}×',
                      style: TextStyle(
                        color: s == speed ? AppColors.gold : AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: changed ? AppColors.goldMuted : Colors.transparent,
                    border: Border.all(color: tint, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      text,
                      style: TextStyle(
                        color: tint,
                        fontSize: text.length > 2 ? 9 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (showLabel) ...[
                  const SizedBox(width: 3),
                  Text('سـرعة',
                      style: TextStyle(
                        color: tint,
                        fontSize: 11,
                        fontWeight:
                            changed ? FontWeight.bold : FontWeight.normal,
                      )),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
