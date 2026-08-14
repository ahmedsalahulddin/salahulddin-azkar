import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/prayer_settings.dart';
import '../services/storage_service.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.goldBorder)),
                  ),
                  child: const Column(
                    children: [
                      Text('⚙️', style: TextStyle(fontSize: 32)),
                      SizedBox(height: 4),
                      Text('الإعدادات',
                          style: TextStyle(color: AppColors.gold, fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),

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

                // About
                _sectionTitle('عن التطبيق'),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.blackCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: const Column(
                    children: [
                      Text('salahulddin-AZKAR',
                          style: TextStyle(color: AppColors.gold, fontSize: 22, fontWeight: FontWeight.bold)),
                      SizedBox(height: 4),
                      Text('الإصدار 1.0.0',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                      SizedBox(height: 10),
                      Text(
                        'تطبيق لأذكار المسلم اليومية من القرآن والسنة الصحيحة',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.6),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Each authority sets its own twilight angles, so this is not a matter of
  /// taste: Makkah's method in Cairo gives the wrong Isha, by a quarter of an
  /// hour or more.
  Widget _prayerMethod() {
    return ValueListenableBuilder<PrayerMethod>(
      valueListenable: PrayerSettings.method,
      builder: (context, chosen, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Column(
          children: [
            for (final method in PrayerMethod.values)
              InkWell(
                onTap: () => PrayerSettings.setMethod(method),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      Icon(
                        method == chosen
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: method == chosen
                            ? AppColors.gold
                            : AppColors.textMuted,
                        size: 19,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(method.label,
                                style: TextStyle(
                                    color: method == chosen
                                        ? AppColors.gold
                                        : AppColors.textPrimary,
                                    fontSize: 14)),
                            Text(method.where,
                                style: const TextStyle(
                                    color: AppColors.textMuted, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
