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
import 'data/tafsir_data.dart';
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/account_screen.dart';
import 'screens/tahfeez/tahfeez_tab.dart';
import 'services/auth_service.dart';
import 'services/custom_reminders.dart';
import 'services/notification_router.dart';
import 'services/tahfeez_service.dart';
import 'services/notification_service.dart';
import 'services/push_service.dart';
import 'services/adhan_downloads.dart';
import 'services/library_bookmarks.dart';
import 'services/recitation_downloads.dart';
import 'services/daily_reminders.dart';
import 'services/dhikr_reminder.dart';
import 'services/prayer_alerts.dart';
import 'services/prayer_service.dart';
import 'services/app_locale.dart';
import 'services/playback_speed.dart';
import 'services/prayer_settings.dart';
import 'services/prayer_place.dart';
import 'services/duas_service.dart';
import 'services/section_config.dart';
import 'services/sync_service.dart';
import 'l10n/strings.dart';
import 'widgets/dhikr_text.dart';
import 'widgets/frame_tuning.dart';
import 'widgets/mushaf_frames.dart';
import 'widgets/mushaf_palettes.dart';
import 'widgets/welcome_screen.dart';

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
      androidNotificationChannelId: 'com.salahulddin.azkar.audio',
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
  try {
    await DuasService.loadBase();
  } catch (_) {}

  await AppLocale.load();
  await DhikrLangPref.load();
  await PlaybackSpeed.load();
  await PrayerSettings.load();
  await PrayerPlace.load();
  unawaited(TafsirService.dropRetired());
  PrayerAlerts.onChanged = NotificationService.schedulePrayerAlerts;
  await PrayerAlerts.load();
  await DhikrReminder.load();
  DailyReminders.onChanged = NotificationService.scheduleDailyReminders;
  await DailyReminders.load();
  CustomReminders.onChanged = NotificationService.scheduleCustomReminders;
  await CustomReminders.load();
  // Before any alert is laid: a downloaded adhan is the alert sound only
  // once it is known to be on the device.
  await AdhanDownloads.refresh();
  unawaited(AdhanDownloads.cacheBundled());
  unawaited(RecitationDownloads.refresh());
  unawaited(LibraryBookmarks.load());
  // The chosen Mushaf border, so the first page opens already wearing it —
  // and where the reader has placed it.
  await MushafFrames.load();
  await FrameTuning.load();
  await MushafPalettes.load();

  try {
    await NotificationService.init();
    // Messages from the app's server; never holds up the launch.
    unawaited(PushService.init());
    await NotificationService.requestPermission();
    // The morning and evening adhkar are laid down by DailyReminders now, at
    // the hour the reader chose. This clears the old fixed-hour pair, which is
    // still sitting in Android's alarm manager on phones that once had it on.
    await NotificationService.clearLegacyAdhkarAlerts();
    await DhikrReminder.reschedule();
    await NotificationService.scheduleDailyReminders();
    await NotificationService.scheduleCustomReminders();
    // Prayer alerts are laid down from today's computed times, which until
    // now only ever existed once the home screen's prayer-times card had
    // built and loaded them — a reader who enabled the alerts but never
    // scrolled to that card in a session had every setting on and nothing
    // scheduled. Lay them down at launch too, the same way the other two
    // reminder kinds already are.
    if (PrayerAlerts.anyOn) {
      unawaited(PrayerService.load());
    }
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
      navigatorKey: NotificationRouter.navigatorKey,
      title: 'SalaHulddin Azkar',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Every route ends above the phone's navigation bar — screens added
      // later inherit this without having to remember it.
      builder: (context, child) => ValueListenableBuilder<String>(
        valueListenable: AppLocale.locale,
        builder: (_, locale, __) => Directionality(
          textDirection: AppLocale.direction,
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

  static const _tahfeezIndex = 2;

  /// Tahfeez is built on accounts. On iPhone, while no sign-in is switched on
  /// for the project (see AuthService.offeredOn), the tab would be a page of
  /// "coming soon" — which App Review treats as unfinished — so it is left
  /// out of the bar until sign-in appears, and returns by itself after.
  bool get _showTahfeez =>
      AuthService.availableProviders.value.isNotEmpty ||
      AuthService.user.value != null ||
      kIsWeb ||
      defaultTargetPlatform != TargetPlatform.iOS;

  static const _promptKey = 'notification_prompt_shown';

  @override
  void initState() {
    super.initState();
    AppLocale.locale.addListener(_onLocale);
    AuthService.user.addListener(TahfeezService.refreshPendingBadge);
    TahfeezService.refreshPendingBadge();
    if (!kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // A reminder tapped while the app was closed opens its surah now,
        // and the welcome tour waits for another launch.
        final fromReminder = NotificationRouter.flushPending();
        _checkForUpdate();
        _startupPrompts(welcome: !fromReminder);
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

  /// One at a time, so they never stack: the welcome tour, then the
  /// notifications prompt, then what's new.
  Future<void> _startupPrompts({required bool welcome}) async {
    if (welcome) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      await showWelcomeIfNeeded(context);
    }
    if (!mounted) return;
    await _checkNotifications();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await _checkWhatsNew();
  }

  static const _updateAskedKey = 'update_prompt_asked_at';

  /// An update is offered, never forced: Google Play's small "update?"
  /// prompt (a flexible update) at most once every three days, a background
  /// download if the reader agrees, then a bar to restart into it when they
  /// choose. Saying no — or ignoring the bar — keeps the current version.
  Future<void> _checkForUpdate() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_updateAskedKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - last < const Duration(days: 3).inMilliseconds) return;
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable ||
          !info.flexibleUpdateAllowed) {
        return;
      }
      await prefs.setInt(_updateAskedKey, now);
      final result = await InAppUpdate.startFlexibleUpdate();
      if (result != AppUpdateResult.success || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t('update.ready')),
          duration: const Duration(seconds: 10),
          backgroundColor: AppColors.blackCard,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: t('update.restart'),
            textColor: AppColors.gold,
            onPressed: () =>
                InAppUpdate.completeFlexibleUpdate().catchError((_) {}),
          ),
        ),
      );
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
    await showDialog<void>(
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

  /// The release _showWhatsNew's list describes. Later releases with nothing
  /// readers would notice leave it alone, so a reader who already saw this
  /// list isn't shown it again.
  static const _whatsNewFor = '1.6.47';

  /// Whether dotted version [a] comes before [b] ("1.6.9" < "1.6.10").
  static bool _versionBefore(String a, String b) {
    final x = a.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    final y = b.split('.').map((p) => int.tryParse(p) ?? 0).toList();
    for (var i = 0; i < x.length || i < y.length; i++) {
      final l = i < x.length ? x[i] : 0;
      final r = i < y.length ? y[i] : 0;
      if (l != r) return l < r;
    }
    return false;
  }

  Future<void> _checkWhatsNew() async {
    if (!mounted) return;
    final info = await PackageInfo.fromPlatform();
    final version = info.version; // e.g. "1.1.0"
    final prefs = await SharedPreferences.getInstance();
    final seen = prefs.getString(_whatsNewKey);
    if (seen == version) return;
    await prefs.setString(_whatsNewKey, version);
    // A first install has nothing "new" to show — the language notice and
    // permission prompts are enough for a first launch.
    if (seen == null) return;
    if (!_versionBefore(seen, _whatsNewFor)) return;
    if (!mounted) return;
    _showWhatsNew(version);
  }

  void _showWhatsNew(String version) {
    // This version's own changes, in the reader's language. Keep it to what
    // actually changed — an old list here points readers at things that
    // have moved or, on iPhone, do not exist.
    final items = [('⏰', t('wn.myremTitle'), t('wn.myremSub'))];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: AppLocale.direction,
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
                      t('wn.title'),
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
                      t('wn.gotIt'),
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        AuthService.availableProviders,
        AuthService.user,
      ]),
      builder: (context, _) => _scaffold(),
    );
  }

  Widget _scaffold() {
    final showTahfeez = _showTahfeez;
    // The bar's positions, as indexes into [_screens].
    final tabs = [
      for (var i = 0; i < _screens.length; i++)
        if (i != _tahfeezIndex || showTahfeez) i,
    ];
    if (!tabs.contains(_currentIndex)) _currentIndex = 1;
    // After the frame: listeners may open a sheet, which can't happen
    // mid-build.
    final onTahfeez = _currentIndex == _tahfeezIndex;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => TahfeezTab.visible.value = onTahfeez,
    );
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
            currentIndex: tabs.indexOf(_currentIndex),
            onTap: (i) => setState(() => _currentIndex = tabs[i]),
            backgroundColor: AppColors.blackCard,
            selectedItemColor: AppColors.gold,
            unselectedItemColor: AppColors.textMuted,
            selectedFontSize: 12,
            unselectedFontSize: 12,
            type: BottomNavigationBarType.fixed,
            items: [for (final i in tabs) _item(i)],
          ),
        ),
      ),
    );
  }

  BottomNavigationBarItem _item(int screen) => switch (screen) {
    0 => BottomNavigationBarItem(
      icon: const Icon(Icons.star_rounded),
      label: t('nav.adhkar'),
    ),
    1 => BottomNavigationBarItem(
      icon: const Icon(Icons.home_rounded),
      label: t('nav.home'),
    ),
    2 => BottomNavigationBarItem(
      icon: const Icon(Icons.school_rounded),
      label: t('nav.tahfeez'),
    ),
    _ => BottomNavigationBarItem(
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
  };
}
