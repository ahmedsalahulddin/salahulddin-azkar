import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/lessons.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';
import 'lesson_screen.dart';

/// The lessons shelf, in two halves.
///
/// The teachings come first because they are here now: each is built from
/// verses of the bundled Mushaf and hadiths of the bundled collections, and
/// names the place every text comes from. Under them sit the video series,
/// still waiting on a channel and saying so on each card rather than opening
/// onto nothing.
class LessonsScreen extends StatelessWidget {
  const LessonsScreen({super.key});

  static const _lessons = [
    (
      icon: '🧒',
      title: 'lessons.kids.title',
      subtitle: 'lessons.kids.subtitle',
      detail: 'lessons.kids.detail',
    ),
    (
      icon: '🕌',
      title: 'lessons.prophets.title',
      subtitle: 'lessons.prophets.subtitle',
      detail: 'lessons.prophets.detail',
    ),
    (
      icon: '📜',
      title: 'lessons.tafsir.title',
      subtitle: 'lessons.tafsir.subtitle',
      detail: 'lessons.tafsir.detail',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(t('lib2.lessonsScreenTitle')),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              t('lib2.teachingsSectionHeader'),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              t('lib2.teachingsSectionDescription'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 12),
            for (final lesson in Lessons.all) ...[
              _lessonCard(context, lesson),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            Text(
              t('lib2.onTheChannelSectionHeader'),
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.play_circle_outline,
                    color: AppColors.gold,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      t('lib2.channelEpisodesComingDescription'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            for (final lesson in _lessons) ...[
              _card(lesson),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _lessonCard(BuildContext context, Lesson lesson) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LessonScreen(lesson: lesson)),
      ),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(lesson.icon, style: const TextStyle(fontSize: 21)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lesson.title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lesson.summary,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AppLocale.isRtl ? Icons.chevron_left : Icons.chevron_right,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(
    ({String icon, String title, String subtitle, String detail}) lesson,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    lesson.icon,
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t(lesson.title),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      t(lesson.subtitle),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Text(
                  t('lib2.comingSoonBadge'),
                  style: const TextStyle(
                    color: AppColors.textGold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t(lesson.detail),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
