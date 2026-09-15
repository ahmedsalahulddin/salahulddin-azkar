import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/stories_data.dart';
import '../l10n/strings.dart';
import '../widgets/bilingual_text.dart';
import 'story_screen.dart';

/// The stories filed under one category, as a simple tappable list.
class StoryCategoryScreen extends StatelessWidget {
  final StoryCategory category;

  const StoryCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final list = getStoriesByCategory(category.id);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: BilingualText(
            tBoth('story.cat.${category.id}'),
            style: const TextStyle(
                color: AppColors.gold, fontSize: 17, fontWeight: FontWeight.w600),
            maxLines: 2,
          ),
          centerTitle: true,
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.goldBorder)),
              ),
              child: Text(
                category.description,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(14),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final story = list[i];
                  return GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StoryScreen(story: story),
                      ),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppColors.blackCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              story.title,
                              style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          const Icon(Icons.chevron_left,
                              color: AppColors.textMuted, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
