import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/adhans.dart';
import '../data/quran_data.dart';
import '../l10n/strings.dart';
import '../services/adhan_downloads.dart';
import '../services/notification_service.dart';
import '../services/prayer_alerts.dart';

/// The two moments a prayer announces itself, each with its own settings.
///
/// Laid out as the reader described it: the early warning and its lead time
/// first, then the call itself and the adhan it plays. Notification and sound
/// are separate switches, so both can be on at once.
class PrayerAlertsScreen extends StatefulWidget {
  const PrayerAlertsScreen({super.key});

  @override
  State<PrayerAlertsScreen> createState() => _PrayerAlertsScreenState();
}

class _PrayerAlertsScreenState extends State<PrayerAlertsScreen> {
  Future<void> _testSound() async {
    final error = await NotificationService.sendPrayerSoundTest();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? t('adh.adhanTestSentMsg')
              : '${t('adh.adhanTestFailedMsg')}\n$error',
          textDirection: TextDirection.rtl,
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(t('adh.prayerAlertsScreenTitle')),
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
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _testSound,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: AppColors.blackCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: Text(
                    t('adh.tryAdhanSoundButton'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                t('adh.alertsAutoUpdateNote'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  height: 1.7,
                ),
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
          Text(
            when.label,
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t('adh.tapHeadingHint'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5),
          ),
          const SizedBox(height: 10),
          _row(
            label: t('adh.allLabel'),
            mode: _commonMode(when),
            onNotify: (v) =>
                PrayerAlerts.setAll(when, _commonMode(when).withNotify(v)),
            onSound: (v) =>
                PrayerAlerts.setAll(when, _commonMode(when).withSound(v)),
            heading: true,
          ),
          const Divider(color: AppColors.goldBorder, height: 18),
          for (final prayer in AlertPrayer.values) ...[
            _row(
              label: prayer.displayName,
              mode: PrayerAlerts.modeFor(prayer, when),
              onNotify: (v) => PrayerAlerts.setMode(
                prayer,
                when,
                PrayerAlerts.modeFor(prayer, when).withNotify(v),
              ),
              onSound: (v) => PrayerAlerts.setMode(
                prayer,
                when,
                PrayerAlerts.modeFor(prayer, when).withSound(v),
              ),
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
          child: Text(
            label,
            style: TextStyle(
              color: heading ? AppColors.gold : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: heading ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
        Expanded(
          child: _toggle(t('adh.notifyToggleLabel'), mode.notify, onNotify),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _toggle(t('adh.soundToggleLabel'), mode.sound, onSound),
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
          border: Border.all(color: on ? AppColors.gold : AppColors.goldBorder),
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
            Text(
              t(
                'adh.leadTimeTemplate',
              ).replaceFirst('%s', QuranService.toArabicDigits(lead)),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
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
                                  : AppColors.goldBorder,
                            ),
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

  /// The adhans, each with what it needs: a download for the ones that are not
  /// on the device, and a note for the ones that cannot be a notification
  /// sound even once they are.
  Widget _adhanPicker(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: PrayerAlerts.adhan,
      builder: (context, chosenId, _) => ValueListenableBuilder<Set<String>>(
        valueListenable: AdhanDownloads.ready,
        builder: (context, ready, _) => ValueListenableBuilder<String?>(
          valueListenable: AdhanDownloads.downloading,
          builder: (context, busy, _) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.blackCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  t('adh.adhanSectionTitle'),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t('adh.adhanBundledNote'),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 10.5,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                for (final adhan in Adhans.all)
                  _adhanRow(context, adhan, chosenId, ready, busy),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Why a downloaded adhan can be heard but not set.
  void _sayDownloadOnly(BuildContext context, Adhan adhan) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            t('adh.adhanListenOnlyTemplate').replaceFirst('%s', adhan.name),
            textAlign: TextAlign.right,
          ),
          backgroundColor: AppColors.blackCard,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  Widget _adhanRow(
    BuildContext context,
    Adhan adhan,
    String chosenId,
    Set<String> ready,
    String? busy,
  ) {
    final chosen = adhan.id == chosenId;
    final here = adhan.isBundled || ready.contains(adhan.id);
    final loading = busy == adhan.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        // Only a bundled adhan can be the alert's sound — Android reads that
        // from inside the app and cannot reach a file the app downloaded. The
        // row still answers a tap, and says so: one that looks exactly like
        // its neighbours and does nothing when pressed reads as broken, which
        // is worse than a refusal that explains itself.
        onTap: () => adhan.isBundled
            ? PrayerAlerts.setAdhan(adhan.id)
            : _sayDownloadOnly(context, adhan),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: chosen ? AppColors.goldMuted : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: chosen ? AppColors.gold : AppColors.goldBorder,
            ),
          ),
          child: Row(
            children: [
              Icon(
                adhan.isBundled
                    ? (chosen
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked)
                    : (here
                          ? Icons.check_circle_outline
                          : Icons.cloud_outlined),
                size: 17,
                color: chosen ? AppColors.gold : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      adhan.name,
                      style: TextStyle(
                        color: chosen ? AppColors.gold : AppColors.textPrimary,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      adhan.isBundled
                          ? adhan.place
                          : here
                          ? t('adh.onDeviceListenOnly')
                          : adhan.place,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (!adhan.isBundled)
                loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.gold,
                        ),
                      )
                    : TextButton(
                        onPressed: busy != null
                            ? null
                            : () async {
                                if (here) {
                                  await AdhanDownloads.remove(adhan);
                                  return;
                                }
                                final ok = await AdhanDownloads.fetch(adhan);
                                if (!context.mounted) return;
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        t(
                                          'adh.downloadFailedTemplate',
                                        ).replaceFirst('%s', adhan.name),
                                        textAlign: TextAlign.right,
                                      ),
                                      backgroundColor: AppColors.blackCard,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                        child: Text(
                          here
                              ? t('adh.deleteButtonLabel')
                              : t('adh.downloadButtonLabel'),
                          style: TextStyle(
                            color: here ? AppColors.textMuted : AppColors.gold,
                            fontSize: 12,
                          ),
                        ),
                      ),
            ],
          ),
        ),
      ),
    );
  }
}
