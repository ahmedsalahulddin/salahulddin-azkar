import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/quran_data.dart';
import '../services/prayer_alerts.dart';

/// Every prayer with its two alerts, and three ways for each to arrive.
///
/// Ten rows on one page rather than a screen per prayer: the reader almost
/// always wants the same setting across all five, and comparing them is the
/// whole task.
class PrayerAlertsScreen extends StatelessWidget {
  const PrayerAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('تنبيهات المواقيت'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: ValueListenableBuilder<Map<String, AlertMode>>(
          valueListenable: PrayerAlerts.settings,
          builder: (context, _, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _leadPicker(),
              const SizedBox(height: 8),
              for (final prayer in AlertPrayer.values) ...[
                _prayerCard(prayer),
                const SizedBox(height: 12),
              ],
              const Text(
                'التنبيهات تُضبط على مواقيت يومك وتُجدَّد كل يوم. '
                'الصوت والاهتزاز يتبعان إعدادات جهازك لهذا التطبيق.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 11, height: 1.7),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// How far ahead the early alert comes — one setting for all five, since
  /// nobody wants ten minutes before Fajr and twenty before Asr.
  Widget _leadPicker() {
    return ValueListenableBuilder<int>(
      valueListenable: PrayerAlerts.lead,
      builder: (context, lead, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 2, bottom: 8),
              child: Text('التنبيه المبكر يأتي قبل الأذان بـ',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
            Row(
              children: [
                for (final minutes in PrayerAlerts.leadChoices)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => PrayerAlerts.setLead(minutes),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: minutes == lead
                                ? AppColors.goldMuted
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: minutes == lead
                                    ? AppColors.gold
                                    : AppColors.goldBorder),
                          ),
                          child: Text(
                            QuranService.toArabicDigits(minutes),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: minutes == lead
                                  ? AppColors.gold
                                  : AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: minutes == lead
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                const Text('دقيقة',
                    style:
                        TextStyle(color: AppColors.textMuted, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _prayerCard(AlertPrayer prayer) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(prayer.name,
              style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          for (final when in AlertWhen.values) ...[
            _modeRow(prayer, when),
            if (when != AlertWhen.values.last) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _modeRow(AlertPrayer prayer, AlertWhen when) {
    final current = PrayerAlerts.modeFor(prayer, when);

    return Row(
      children: [
        SizedBox(
          width: 96,
          child: Text(when.label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.3)),
        ),
        for (final mode in AlertMode.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => PrayerAlerts.setMode(prayer, when, mode),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: mode == current
                        ? AppColors.goldMuted
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(
                        color: mode == current
                            ? AppColors.gold
                            : AppColors.goldBorder),
                  ),
                  child: Column(
                    children: [
                      Text(mode.icon, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(
                        mode.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: mode == current
                              ? AppColors.gold
                              : AppColors.textMuted,
                          fontSize: 9.5,
                          fontWeight: mode == current
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
