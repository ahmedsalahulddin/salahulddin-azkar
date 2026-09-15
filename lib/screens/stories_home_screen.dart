import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/stories_data.dart';
import '../l10n/strings.dart';
import '../widgets/bilingual_text.dart';
import 'story_category_screen.dart';

/// A grid of story categories — miracles, prophets, animals, and so on —
/// each opening to the stories filed under it.
class StoriesHomeScreen extends StatelessWidget {
  const StoriesHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cats = getStoryCategoriesWithCount();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(t('shelf.stories.title')),
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
          itemCount: cats.length,
          itemBuilder: (context, i) {
            final cat = cats[i];
            return GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StoryCategoryScreen(category: cat),
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
                      tBoth('story.cat.${cat.id}'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${cat.count} ${t('story.countSuffix')}',
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 11)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
