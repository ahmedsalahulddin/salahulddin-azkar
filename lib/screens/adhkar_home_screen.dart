import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/adhkar_data.dart';
import '../data/hisn_data.dart';
import '../data/umrah_data.dart';
import '../data/home_shelves.dart';
import '../l10n/strings.dart';
import '../widgets/bilingual_text.dart';
import '../widgets/tasbih_counter.dart';
import 'category_screen.dart';
import 'deceased_screen.dart';
import 'sahih_adhkar_screen.dart';
import 'umrah_screen.dart';

class AdhkarHomeScreen extends StatelessWidget {
  const AdhkarHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cats = getCategoriesWithCount();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('الأذكار'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.05,
          ),
          // +3 for the Hisn al-Muslim, Umrah and tasbih tiles, which lead the
          // grid.
          itemCount: cats.length + 3,
          itemBuilder: (context, i) {
            if (i == 0) return _sahihCard(context);
            if (i == 1) return _umrahCard(context);
            if (i == 2) return _tasbihCard(context);
            final cat = cats[i - 3];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => cat.id == 'deceased'
                      ? const DeceasedScreen()
                      : CategoryScreen(category: cat),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.blackCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(cat.icon, style: const TextStyle(fontSize: 32)),
                    const SizedBox(height: 8),
                    BilingualText(
                      tBoth('adhkar.cat.${cat.id}'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${cat.count} ذكر',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// The counter lives with the adhkar now that the home screen is four
  /// shelves rather than a grid of loose tiles.
  Widget _tasbihCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => const TasbihCounter(dhikr: freeTasbih)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🔢', style: TextStyle(fontSize: 32)),
            SizedBox(height: 8),
            Text('عداد التسبيح',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 4),
            Text('سبّح واحتسب',
                style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _umrahCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const UmrahScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.navyLight, AppColors.navy],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🕋', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            const Text(
              'أدعية العمرة',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilder<int>(
              future: UmrahGuide.totalDuas(),
              builder: (context, snapshot) => Text(
                snapshot.data == null
                    ? 'على خطوات النسك'
                    : '${snapshot.data} دعاءً',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Leads the grid, so it sits alongside the morning adhkar tile.
  Widget _sahihCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SahihAdhkarScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.navyLight, AppColors.navy],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🕋', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            const Text(
              HisnService.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.gold,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            FutureBuilder<List<HisnChapter>>(
              future: HisnService.chapters(),
              builder: (context, snapshot) {
                final chapters = snapshot.data;
                return Text(
                  chapters == null
                      ? 'حصن المسلم'
                      : '${chapters.length} باباً',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 11),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
