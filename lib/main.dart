import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'constants/theme.dart';
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/account_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/prayer_settings.dart';
import 'services/section_config.dart';
import 'services/storage_service.dart';
import 'widgets/mushaf_frames.dart';
import 'widgets/mushaf_palettes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.black,
    statusBarIconBrightness: Brightness.light,
  ));
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
  try {
    await SectionConfig.load();
  } catch (_) {}

  // The chosen Mushaf border, so the first page opens already wearing it.
  await PrayerSettings.load();
  await MushafFrames.load();
  await MushafPalettes.load();

  try {
    await NotificationService.init();
    await NotificationService.requestPermission();
    final morningOn = await StorageService.getMorningNotif();
    final eveningOn = await StorageService.getEveningNotif();
    await NotificationService.scheduleMorning(morningOn);
    await NotificationService.scheduleEvening(eveningOn);
  } catch (_) {}
  runApp(const NoorAzkarApp());
}

class NoorAzkarApp extends StatelessWidget {
  const NoorAzkarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'salahulddin-AZKAR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Every route ends above the phone's navigation bar — screens added
      // later inherit this without having to remember it.
      builder: (context, child) =>
          SafeArea(top: false, left: false, right: false, child: child!),
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
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: Container(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.goldBorder, width: 1)),
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
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.star_rounded), label: 'أذكاري'),
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'الرئيسية'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded), label: 'حسابي'),
            ],
          ),
        ),
      ),
    );
  }
}
