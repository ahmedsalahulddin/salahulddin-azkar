import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';
import '../services/auth_service.dart';
import 'sign_in_buttons.dart';

const _hiddenKey = 'welcome_hidden';

/// Opens the welcome tour unless the reader has ticked "don't show this
/// again" on it before. Completes when the tour is closed.
Future<void> showWelcomeIfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool(_hiddenKey) == true || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => const WelcomeScreen(),
    ),
  );
}

/// What the app offers, in a few lines each: the shelves on Home,
/// Favourites, My reminders, the adhan, Tahfeez, and that none of it needs
/// a Google account. Shown at launch until the reader asks it not to be.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _dontShow = false;

  /// Drives the star that glows on and off and the hand that points at
  /// My reminders, so the eye lands on them.
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  static const _items = [
    (Icons.home_rounded, 'home'),
    (Icons.star_rounded, 'fav'),
    (Icons.alarm_add_rounded, 'rem'),
    (Icons.mosque, 'adhan'),
    (Icons.school_rounded, 'tahfeez'),
    (Icons.no_accounts_outlined, 'sign'),
  ];

  Future<void> _close() async {
    if (_dontShow) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_hiddenKey, true);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Scaffold(
          backgroundColor: AppColors.black,
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                    children: [
                      _header(),
                      const SizedBox(height: 22),
                      for (final (icon, key) in _items) ...[
                        _feature(icon, key),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.menu_book_outlined,
                            color: AppColors.textMuted,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              t('welcome.more'),
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _footer(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.goldBorder, width: 1.5),
            boxShadow: const [
              BoxShadow(
                color: AppColors.goldMuted,
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(21),
            child: Image.asset(
              'assets/images/app_icon.jpg',
              width: 84,
              height: 84,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          t('welcome.title'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          t('welcome.sub'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
        ),
      ],
    );
  }

  Widget _feature(IconData icon, String key) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.goldMuted,
              shape: BoxShape.circle,
            ),
            child: _leading(icon, key),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('welcome.${key}T'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  t('welcome.${key}B'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _leading(IconData icon, String key) {
    final still = MediaQuery.of(context).disableAnimations;
    switch (key) {
      case 'fav':
        return AnimatedBuilder(
          animation: _pulse,
          builder: (_, _) {
            final v = still ? 1.0 : Curves.easeInOut.transform(_pulse.value);
            return Transform.scale(
              scale: 0.85 + 0.3 * v,
              child: Icon(
                Icons.star_rounded,
                size: 24,
                color: Color.lerp(AppColors.goldDark, AppColors.goldLight, v),
                shadows: [
                  Shadow(
                    color: AppColors.goldLight.withValues(alpha: 0.9 * v),
                    blurRadius: 14 * v,
                  ),
                ],
              ),
            );
          },
        );
      case 'rem':
        // The hand points from the icon's side toward the words.
        final rtl = AppLocale.direction == TextDirection.rtl;
        return AnimatedBuilder(
          animation: _pulse,
          builder: (_, _) {
            final v = still ? 0.0 : Curves.easeInOut.transform(_pulse.value);
            return Transform.translate(
              offset: Offset((rtl ? -5 : 5) * v, 0),
              child: Text(
                rtl ? '👈' : '👉',
                style: const TextStyle(fontSize: 22, height: 1),
              ),
            );
          },
        );
      case 'sign':
        // The accounts this phone signs in with: Google, and Apple on iPhone.
        final apple = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
        return apple
            ? const SizedBox(
                width: 38,
                height: 38,
                child: Stack(
                  children: [
                    PositionedDirectional(
                      start: 0,
                      top: 0,
                      child: _Badge.google(),
                    ),
                    PositionedDirectional(
                      end: 0,
                      bottom: 0,
                      child: _Badge.apple(),
                    ),
                  ],
                ),
              )
            : const _Badge.google(size: 34);
    }
    return Icon(icon, color: AppColors.gold, size: 20);
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.goldBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => setState(() => _dontShow = !_dontShow),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Checkbox(
                    value: _dontShow,
                    onChanged: (v) => setState(() => _dontShow = v ?? false),
                    activeColor: AppColors.gold,
                    checkColor: AppColors.black,
                    side: const BorderSide(color: AppColors.gold, width: 1.5),
                  ),
                  Expanded(
                    child: Text(
                      t('welcome.dontShow'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _close,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                t('welcome.start'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A brand mark on its brand's own round ground: Google on white, Apple on
/// black.
class _Badge extends StatelessWidget {
  final SignInProvider provider;
  final double size;

  const _Badge.google({this.size = 24}) : provider = SignInProvider.google;
  const _Badge.apple() : provider = SignInProvider.apple, size = 24;

  @override
  Widget build(BuildContext context) {
    final google = provider == SignInProvider.google;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: google ? Colors.white : Colors.black,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: BrandMark(provider, size: size * 0.58),
    );
  }
}
