import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:geolocator/geolocator.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/theme.dart';
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/account_screen.dart';
import 'screens/tahfeez/tahfeez_tab.dart';
import 'services/auth_service.dart';
import 'services/tahfeez_lang.dart';
import 'services/tahfeez_service.dart';
import 'services/notification_service.dart';
import 'services/adhan_downloads.dart';
import 'services/daily_reminders.dart';
import 'services/dhikr_reminder.dart';
import 'services/prayer_alerts.dart';
import 'services/app_locale.dart';
import 'services/playback_speed.dart';
import 'services/prayer_settings.dart';
import 'services/section_config.dart';
import 'services/sync_service.dart';
import 'l10n/strings.dart';
import 'widgets/dhikr_text.dart';
import 'widgets/frame_tuning.dart';
import 'widgets/mushaf_frames.dart';
import 'widgets/mushaf_palettes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.black,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  // Lets recitation keep playing once the reader leaves the app, and puts the
  // controls in the notification shade and on the lock screen. Must run before
  // any player is built.
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'app.yallanow.azkar.audio',
      androidNotificationChannelName: 'التلاوة',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
  } catch (_) {
    // Playback still works in the foreground if the service cannot start.
  }

  // No-op until the project credentials are supplied; the app runs as a guest.
  try {
    await AuthService.init();
  } catch (_) {}

  // Reads the cached layout and refreshes in the background. Never blocks the
  // first frame, and shows every section if it cannot reach the project.
  SectionConfig.onApplied = MushafFrames.reconcile;
  try {
    await SectionConfig.load();
  } catch (_) {}

  await AppLocale.load();
  await TahfeezLang.load();
  await DhikrLangPref.load();
  await PlaybackSpeed.load();
  await PrayerSettings.load();
  PrayerAlerts.onChanged = NotificationService.schedulePrayerAlerts;
  await PrayerAlerts.load();
  await DhikrReminder.load();
  DailyReminders.onChanged = NotificationService.scheduleDailyReminders;
  await DailyReminders.load();
  unawaited(AdhanDownloads.refresh());
  // The chosen Mushaf border, so the first page opens already wearing it —
  // and where the reader has placed it.
  await MushafFrames.load();
  await FrameTuning.load();
  await MushafPalettes.load();

  try {
    await NotificationService.init();
    await NotificationService.requestPermission();
    // The morning and evening adhkar are laid down by DailyReminders now, at
    // the hour the reader chose. This clears the old fixed-hour pair, which is
    // still sitting in Android's alarm manager on phones that once had it on.
    await NotificationService.clearLegacyAdhkarAlerts();
    await DhikrReminder.reschedule();
    await NotificationService.scheduleDailyReminders();
  } catch (_) {}
  // Signing in on a second device should bring the reader's marks with it,
  // without them having to find a button first.
  SyncService.watch();

  runApp(const NoorAzkarApp());
}

class NoorAzkarApp extends StatelessWidget {
  const NoorAzkarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SalaHulddin Azkar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Every route ends above the phone's navigation bar — screens added
      // later inherit this without having to remember it.
      builder: (context, child) => ValueListenableBuilder<String>(
        valueListenable: AppLocale.locale,
        builder: (_, locale, __) => Directionality(
          textDirection: locale == 'en' ? TextDirection.ltr : TextDirection.rtl,
          child: SafeArea(top: false, left: false, right: false, child: child!),
        ),
      ),
      home: const MainNavigation(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  // Land on الرئيسية (prayer times + sections), not the favorites tab.
  int _currentIndex = 1;

  final _screens = const [
    FavoritesScreen(),
    HomeScreen(),
    TahfeezTab(),
    AccountScreen(),
  ];

  static const _promptKey = 'notification_prompt_shown';

  @override
  void initState() {
    super.initState();
    AppLocale.locale.addListener(_onLocale);
    AuthService.user.addListener(TahfeezService.refreshPendingBadge);
    TahfeezService.refreshPendingBadge();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkNotifications();
        _checkForUpdate();
        Future<void>.delayed(const Duration(milliseconds: 600), _checkWhatsNew);
      });
    }
  }

  @override
  void dispose() {
    AppLocale.locale.removeListener(_onLocale);
    AuthService.user.removeListener(TahfeezService.refreshPendingBadge);
    super.dispose();
  }

  void _onLocale() => setState(() {});

  Future<void> _checkForUpdate() async {
    if (!Platform.isAndroid) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.performImmediateUpdate();
      }
    } catch (_) {
      // Not distributed via Play Store (debug builds, direct APK) — ignore.
    }
  }

  Future<void> _checkNotifications() async {
    final allowed = await NotificationService.allowed();
    if (allowed != false) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_promptKey) == true) return;
    await prefs.setBool(_promptKey, true);
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.goldBorder),
          ),
          title: const Row(
            children: [
              Icon(Icons.notifications_active, color: AppColors.gold, size: 24),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'السماح بالإشعارات',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'التطبيق يحتاج الإشعارات عشان يذكّرك بأذكار الصباح والمساء'
            ' وأوقات الصلاة.\n\n'
            'افتح إعدادات التطبيق وفعّل الإشعارات.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'لاحقاً',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Geolocator.openAppSettings();
              },
              child: const Text(
                'فتح الإعدادات',
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const _whatsNewKey = 'whats_new_seen';

  Future<void> _checkWhatsNew() async {
    if (!mounted) return;
    final info = await PackageInfo.fromPlatform();
    final version = info.version; // e.g. "1.1.0"
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_whatsNewKey) == version) return;
    await prefs.setString(_whatsNewKey, version);
    if (!mounted) return;
    _showWhatsNew(version);
  }

  void _showWhatsNew(String version) {
    final isEn = AppLocale.isEn;
    final items = isEn
        ? [
            (
              '🎓',
              'Memorisation tab',
              'Circles, weekly timetable and per-student assessment',
            ),
            ('🧭', 'Qibla compass', 'Points straight to the Kaaba'),
            (
              '📚',
              'Hadith Encyclopedia',
              'Hadiths by topic with explanations, in 8 languages',
            ),
            (
              '🔄',
              'Check for updates',
              'One tap in Account to see if a newer version is out',
            ),
          ]
        : [
            (
              '🎓',
              'تبويب التحفيظ',
              'حلقات وجدول أسبوعي وتقييم لكل طالب في الحصة',
            ),
            ('🧭', 'بوصلة القبلة', 'تشير للكعبة مباشرة'),
            (
              '📚',
              'موسوعة الحديث',
              'أحاديث مبوّبة بالموضوع مع شرحها، بـ٨ لغات',
            ),
            (
              '🔄',
              'التحقق من التحديث',
              'ضغطة واحدة في حسابي تعرف بها إن كان هناك إصدار أحدث',
            ),
          ];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: isEn ? TextDirection.ltr : TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.goldMuted,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: Text(
                        'v$version',
                        style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isEn ? "What's New" : 'ما الجديد',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                for (final (icon, title, sub) in items) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(icon, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              sub,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.goldMuted,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppColors.goldBorder),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      isEn ? 'Got it' : 'فهمت',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: AppColors.goldBorder, width: 1),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (i) => setState(() => _currentIndex = i),
            backgroundColor: AppColors.blackCard,
            selectedItemColor: AppColors.gold,
            unselectedItemColor: AppColors.textMuted,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: const Icon(Icons.star_rounded),
                label: t('nav.adhkar'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.home_rounded),
                label: t('nav.home'),
              ),
              BottomNavigationBarItem(
                icon: const Icon(Icons.school_rounded),
                label: t('nav.tahfeez'),
              ),
              BottomNavigationBarItem(
                icon: ValueListenableBuilder<int>(
                  valueListenable: TahfeezService.adminBadge,
                  builder: (_, n, _) => Badge(
                    isLabelVisible: n > 0,
                    label: Text('$n'),
                    backgroundColor: AppColors.error,
                    child: const Icon(Icons.person_rounded),
                  ),
                ),
                label: t('nav.account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
