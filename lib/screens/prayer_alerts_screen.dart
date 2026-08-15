import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/adhans.dart';
import '../data/quran_data.dart';
import '../services/prayer_alerts.dart';

/// The two moments a prayer announces itself, each with its own settings.
///
/// Laid out as the reader described it: the early warning and its lead time
/// first, then the call itself and the adhan it plays. Notification and sound
/// are separate switches, so both can be on at once.
class PrayerAlertsScreen extends StatelessWidget {
  const PrayerAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('مواقيت الصلاة'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: ValueListenableBuilder<Map<String, AlertMode>>(
          valueListenable: PrayerAlerts.settings,
          builder: (context, _, _) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _section(AlertWhen.before),
              const SizedBox(height: 10),
              _leadPicker(),
              const SizedBox(height: 20),
              _section(AlertWhen.onTime),
              const SizedBox(height: 10),
              _adhanPicker(context),
              const SizedBox(height: 16),
              const Text(
                'التنبيهات تُضبط على مواقيت يومك وتُجدَّد كل يوم.',
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

  /// One moment: its heading, a row that sets all five at once, then the five.
  Widget _section(AlertWhen when) {
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
          Text(when.label,
              style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('اضغط العنوان لضبط الخمس صلوات معاً',
              style: TextStyle(color: AppColors.textMuted, fontSize: 10.5)),
          const SizedBox(height: 10),
          _row(
            label: 'الكل',
            mode: _commonMode(when),
            onNotify: (v) => PrayerAlerts.setAll(
                when, _commonMode(when).withNotify(v)),
            onSound: (v) =>
                PrayerAlerts.setAll(when, _commonMode(when).withSound(v)),
            heading: true,
          ),
          const Divider(color: AppColors.goldBorder, height: 18),
          for (final prayer in AlertPrayer.values) ...[
            _row(
              label: prayer.name,
              mode: PrayerAlerts.modeFor(prayer, when),
              onNotify: (v) => PrayerAlerts.setMode(prayer, when,
                  PrayerAlerts.modeFor(prayer, when).withNotify(v)),
              onSound: (v) => PrayerAlerts.setMode(prayer, when,
                  PrayerAlerts.modeFor(prayer, when).withSound(v)),
            ),
            if (prayer != AlertPrayer.values.last) const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  /// What the five share, or off when they disagree — so the heading row shows
  /// the truth rather than the first prayer's setting.
  static AlertMode _commonMode(AlertWhen when) {
    final modes = [
      for (final p in AlertPrayer.values) PrayerAlerts.modeFor(p, when),
    ];
    final notify = modes.every((m) => m.notify);
    final sound = modes.every((m) => m.sound);
    return AlertMode(notify: notify, sound: sound);
  }

  Widget _row({
    required String label,
    required AlertMode mode,
    required ValueChanged<bool> onNotify,
    required ValueChanged<bool> onSound,
    bool heading = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Text(label,
              style: TextStyle(
                color: heading ? AppColors.gold : AppColors.textSecondary,
                fontSize: 13,
                fontWeight: heading ? FontWeight.bold : FontWeight.normal,
              )),
        ),
        Expanded(
          child: _toggle('📳 إشعار', mode.notify, onNotify),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _toggle('🔔 صوت', mode.sound, onSound),
        ),
      ],
    );
  }

  Widget _toggle(String label, bool on, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!on),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: on ? AppColors.goldMuted : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border:
              Border.all(color: on ? AppColors.gold : AppColors.goldBorder),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: on ? AppColors.gold : AppColors.textMuted,
            fontSize: 11.5,
            fontWeight: on ? FontWeight.bold : FontWeight.normal,
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
            Text('يأتي قبل الأذان بـ ${QuranService.toArabicDigits(lead)} دقيقة',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final minutes in PrayerAlerts.leadChoices)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
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
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _adhanPicker(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: PrayerAlerts.adhan,
      builder: (context, id, _) {
        final chosen = Adhans.byId(id);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.blackCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: PopupMenuButton<String>(
            onSelected: PrayerAlerts.setAdhan,
            color: AppColors.blackSurface,
            position: PopupMenuPosition.under,
            itemBuilder: (context) => [
              for (final adhan in Adhans.all)
                PopupMenuItem(
                  value: adhan.id,
                  child: Row(
                    children: [
                      Icon(
                        adhan.id == id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        size: 17,
                        color: adhan.id == id
                            ? AppColors.gold
                            : AppColors.textMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(adhan.name,
                                style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 13)),
                            Text(adhan.place,
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 10)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            child: Row(
              children: [
                const Icon(Icons.campaign, color: AppColors.gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('الأذان',
                          style: TextStyle(
                              color: AppColors.textMuted, fontSize: 10.5)),
                      Text(chosen.name,
                          style: const TextStyle(
                              color: AppColors.gold, fontSize: 14)),
                    ],
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down,
                    color: AppColors.gold, size: 22),
              ],
            ),
          ),
        );
      },
    );
  }
}
