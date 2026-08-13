import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/theme.dart';
import 'screens/home_screen.dart';
import 'screens/favorites_screen.dart';
import 'screens/settings_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/section_config.dart';
import 'services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.black,
    statusBarIconBrightness: Brightness.light,
  ));
  // No-op until the project credentials are supplied; the app runs as a guest.
  try {
    await AuthService.init();
  } catch (_) {}

  // Reads the cached layout and refreshes in the background. Never blocks the
  // first frame, and shows every section if it cannot reach the project.
  try {
    await SectionConfig.load();
  } catch (_) {}

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
    SettingsScreen(),
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
              BottomNavigationBarItem(icon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
            ],
          ),
        ),
      ),
    );
  }
}
