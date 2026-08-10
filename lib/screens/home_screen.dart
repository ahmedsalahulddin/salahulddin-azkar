import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/adhkar_data.dart';
import '../services/auth_service.dart';
import 'account_screen.dart';
import '../widgets/prayer_times_card.dart';
import '../widgets/tasbih_counter.dart';
import 'adhkar_home_screen.dart';
import 'books_screen.dart';
import 'deceased_screen.dart';
import 'favorites_screen.dart';
import 'quran_home_screen.dart';

/// Free-running tasbih used by the home shortcut (not tied to a specific dhikr).
const _freeTasbih = Dhikr(
  id: 'free-tasbih',
  categoryId: 'tasbih',
  text: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
  source: 'صحيح مسلم',
  repetitions: 33,
);

class _Section {
  final String icon;
  final String title;
  final String subtitle;
  final Color tint;
  final Widget Function() open;

  const _Section(this.icon, this.title, this.subtitle, this.tint, this.open);
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sections = <_Section>[
      _Section('📿', 'الأذكار', '${adhkar.length} ذكر', AppColors.goldMuted,
          () => const AdhkarHomeScreen()),
      _Section('📖', 'القرآن الكريم', 'تدبّر وقراءة', AppColors.emeraldMuted,
          () => const QuranHomeScreen()),
      _Section('📚', 'المكتبة', '١٠ كتب حديث', AppColors.goldMuted,
          () => const BooksScreen()),
      _Section('🔢', 'عداد التسبيح', 'سبّح واحتسب', AppColors.emeraldMuted,
          () => const TasbihCounter(dhikr: _freeTasbih)),
      _Section('🕊️', 'الوفيات', 'ادعُ لموتاك', AppColors.goldMuted,
          () => const DeceasedScreen()),
      _Section('⭐', 'المفضلة', 'أذكاري المحفوظة', AppColors.emeraldMuted,
          () => const FavoritesScreen()),
    ];

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
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppColors.goldBorder)),
                  ),
                  child: Row(
                    children: [
                      // Balances the avatar so the basmala stays centred.
                      const SizedBox(width: 34),
                      const Expanded(
                        child: Text('بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppColors.textMuted, fontSize: 13)),
                      ),
                      ValueListenableBuilder<AppUser?>(
                        valueListenable: AuthService.user,
                        builder: (context, user, _) => GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AccountScreen()),
                          ),
                          behavior: HitTestBehavior.opaque,
                          child: UserAvatar(user: user),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // The verse that names the app's purpose leads the screen.
                _quranQuote(),
                const SizedBox(height: 16),

                const PrayerTimesCard(),
                const SizedBox(height: 20),

                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text('الأقسام',
                      style: TextStyle(
                          color: AppColors.textGold,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)),
                ),

                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: sections.length,
                  itemBuilder: (context, i) => _sectionCard(context, sections[i]),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _quranQuote() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.emeraldMuted,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emerald),
      ),
      // Reference sits beside the verse rather than under it. A Row keeps it
      // there at any width — inline it would break onto its own line as soon
      // as the verse filled the column.
      child: const Row(
        children: [
          Expanded(
            // Scales down rather than wrapping, so the card stays one line
            // tall on a narrow phone instead of growing back to two.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '«أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ»',
                maxLines: 1,
                style: TextStyle(
                    color: AppColors.textPrimary, fontSize: 18, height: 1.5),
              ),
            ),
          ),
          SizedBox(width: 6),
          Text(
            'الرعد: ٢٨',
            // Must not break across lines — it is a citation, not prose.
            softWrap: false,
            maxLines: 1,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _sectionCard(BuildContext context, _Section s) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => s.open()),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: s.tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(child: Text(s.icon, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(height: 10),
            Text(s.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(s.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
