import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../services/auth_service.dart';
import '../services/section_config.dart';
import 'account_screen.dart';
import '../widgets/prayer_times_card.dart';
import 'adhkar_home_screen.dart';
import 'books_screen.dart';
import 'lessons_screen.dart';
import 'quran_home_screen.dart';

/// One of the four shelves the home screen is divided into.
class _Category {
  /// Matches the key in app_sections, so visibility and order can be changed
  /// remotely.
  final String key;
  final String icon;
  final String title;

  /// What is inside, named rather than described — the reader should not have
  /// to open a shelf to find out whether the thing they want is on it.
  final String contents;
  final Color tint;
  final Widget Function() open;

  const _Category(
      this.key, this.icon, this.title, this.contents, this.tint, this.open);
}

// Top-level so the category list can stay const.
Widget _openAdhkar() => const AdhkarHomeScreen();
Widget _openQuran() => const QuranHomeScreen();
Widget _openLessons() => const LessonsScreen();
Widget _openBooks() => const BooksScreen();

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const all = <_Category>[
      _Category('adhkar', '📿', 'الأذكار',
          'الصباح والمساء · حصن المسلم · أدعية العمرة · التسبيح · الوفيات',
          AppColors.goldMuted, _openAdhkar),
      _Category('quran', '📖', 'القرآن الكريم',
          'تلاوة وتدبّر · المصحف كاملاً · اختبار الحفظ',
          AppColors.emeraldMuted, _openQuran),
      _Category('lessons', '🎓', 'الدروس',
          'قصص الأنبياء للأطفال · قصص الأنبياء · التفسير',
          AppColors.goldMuted, _openLessons),
      _Category('library', '📚', 'الكتب والأحاديث',
          'عشرة مجلدات · البخاري ومسلم والسنن · رياض الصالحين',
          AppColors.emeraldMuted, _openBooks),
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

                // Visibility and order can be changed remotely; if that config
                // is unavailable every section shows in its built-in order.
                ValueListenableBuilder<Map<String, SectionSetting>>(
                  valueListenable: SectionConfig.settings,
                  builder: (context, _, _) {
                    final visible = [
                      for (var i = 0; i < all.length; i++)
                        if (SectionConfig.isVisible(all[i].key)) (all[i], i),
                    ]..sort((a, b) => SectionConfig.orderOf(a.$1.key, a.$2)
                        .compareTo(SectionConfig.orderOf(b.$1.key, b.$2)));

                    // One shelf per row, so each is wide enough to name what
                    // it holds instead of leaving the reader to guess from a
                    // two-word tile.
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          for (final (category, _) in visible) ...[
                            _categoryRow(context, category),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    );
                  },
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

  Widget _categoryRow(BuildContext context, _Category c) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => c.open()),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: c.tint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                  child: Text(c.icon, style: const TextStyle(fontSize: 25))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(
                    c.contents,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_left,
                color: AppColors.textMuted, size: 22),
          ],
        ),
      ),
    );
  }
}
