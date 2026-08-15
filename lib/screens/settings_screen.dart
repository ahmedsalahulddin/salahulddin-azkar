import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/quran_data.dart';
import '../services/prayer_alerts.dart';
import '../services/prayer_settings.dart';
import 'prayer_alerts_screen.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  /// True when the settings sit inside another screen's scroll view, which is
  /// how they are reached now — the account page carries them.
  final bool embedded;

  const SettingsScreen({super.key, this.embedded = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _fontSize = 'medium';
  bool _morningNotif = true;
  bool _eveningNotif = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fs = await StorageService.getFontSize();
    final mn = await StorageService.getMorningNotif();
    final en = await StorageService.getEveningNotif();
    if (mounted) {
      setState(() {
        _fontSize = fs;
        _morningNotif = mn;
        _eveningNotif = en;
      });
    }
  }

  Future<void> _setFontSize(String size) async {
    setState(() => _fontSize = size);
    await StorageService.setFontSize(size);
  }

  @override
  Widget build(BuildContext context) {
    final previewSize = _fontSize == 'small' ? 18.0 : _fontSize == 'large' ? 28.0 : 22.0;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

                // Font size section
                _sectionTitle('حجم الخط'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _fontBtn('صغير', 'small'),
                      const SizedBox(width: 8),
                      _fontBtn('متوسط', 'medium'),
                      const SizedBox(width: 8),
                      _fontBtn('كبير', 'large'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.blackCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: Text(
                    'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
                    style: TextStyle(color: AppColors.textPrimary, fontSize: previewSize),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Prayer times
                _sectionTitle('حساب مواقيت الصلاة'),
                _prayerMethod(),
                const SizedBox(height: 10),
                _asrSchool(),
                const SizedBox(height: 10),
                _alertsRow(),

                // Notifications
                _sectionTitle('التذكيرات'),
                _notifRow(
                  'أذكار الصباح',
                  'تذكير يومي الساعة 06:00',
                  _morningNotif,
                  (val) async {
                    setState(() => _morningNotif = val);
                    await StorageService.setMorningNotif(val);
                    await NotificationService.scheduleMorning(val);
                  },
                ),
                const SizedBox(height: 6),
                _notifRow(
                  'أذكار المساء',
                  'تذكير يومي الساعة 17:00',
                  _eveningNotif,
                  (val) async {
                    setState(() => _eveningNotif = val);
                    await StorageService.setEveningNotif(val);
                    await NotificationService.scheduleEvening(val);
                  },
                ),

      ],
    );

    // Embedded, the caller owns the page and its scrolling.
    if (widget.embedded) return body;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('الإعدادات'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: SafeArea(child: SingleChildScrollView(child: body)),

      ),
    );
  }

  /// Each authority sets its own twilight angles, so this is not a matter of
  /// taste: Makkah's method in Cairo gives the wrong Isha, by a quarter of an
  /// hour or more. Left on automatic it follows the reader across borders.
  Widget _prayerMethod() {
    return ValueListenableBuilder<PrayerMethod>(
      valueListenable: PrayerSettings.method,
      builder: (context, chosen, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: PopupMenuButton<PrayerMethod>(
          onSelected: PrayerSettings.setMethod,
          color: AppColors.blackSurface,
          position: PopupMenuPosition.under,
          itemBuilder: (context) => [
            for (final method in PrayerMethod.values)
              PopupMenuItem(
                value: method,
                child: Row(
                  children: [
                    Icon(
                      method == chosen
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      size: 17,
                      color: method == chosen
                          ? AppColors.gold
                          : AppColors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(method.label,
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 13)),
                          Text(method.where,
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chosen.label,
                        style: const TextStyle(
                            color: AppColors.gold, fontSize: 14)),
                    Text(chosen.where,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_down,
                  color: AppColors.gold, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  /// The two rules for Asr are about forty minutes apart in summer.
  Widget _asrSchool() {
    return ValueListenableBuilder<AsrSchool>(
      valueListenable: PrayerSettings.school,
      builder: (context, chosen, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
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
              child: Text('وقت العصر',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ),
            Row(
              children: [
                for (final school in AsrSchool.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => PrayerSettings.setSchool(school),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: school == chosen
                                ? AppColors.goldMuted
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: school == chosen
                                    ? AppColors.gold
                                    : AppColors.goldBorder),
                          ),
                          child: Column(
                            children: [
                              Text(school.label,
                                  style: TextStyle(
                                      color: school == chosen
                                          ? AppColors.gold
                                          : AppColors.textMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold)),
                              Text(school.note,
                                  style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 10)),
                            ],
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

  /// Opens the grid where each prayer's two alerts are set.
  Widget _alertsRow() {
    return ValueListenableBuilder<Map<String, AlertMode>>(
      valueListenable: PrayerAlerts.settings,
      builder: (context, _, __) {
        final on = AlertPrayer.values
            .expand((p) => AlertWhen.values.map((w) => PrayerAlerts.modeFor(p, w)))
            .where((m) => m != AlertMode.off)
            .length;

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrayerAlertsScreen()),
          ),
          behavior: HitTestBehavior.opaque,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.blackCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: AppColors.gold, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تنبيهات المواقيت',
                          style: TextStyle(
                              color: AppColors.textPrimary, fontSize: 14)),
                      Text(
                        on == 0
                            ? 'لا تنبيه مفعّل'
                            : 'مفعّل لـ ${QuranService.toArabicDigits(on)} من عشرة',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left,
                    color: AppColors.textMuted, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(title,
          style: const TextStyle(color: AppColors.textGold, fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _fontBtn(String label, String key) {
    final isActive = _fontSize == key;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setFontSize(key),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? AppColors.goldMuted : AppColors.blackCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isActive ? AppColors.gold : AppColors.goldBorder),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive ? AppColors.gold : AppColors.textMuted,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _notifRow(String title, String desc, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.gold,
            activeTrackColor: AppColors.emerald,
            inactiveTrackColor: AppColors.blackSurface,
          ),
        ],
      ),
    );
  }
}
