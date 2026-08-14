import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/lessons.dart';
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
      title: 'قصص الأنبياء للأطفال',
      subtitle: 'حلقات قصيرة بلغة بسيطة',
      detail: 'من آدم إلى محمد ﷺ، مبسّطة لمن هم دون العاشرة',
    ),
    (
      icon: '🕌',
      title: 'قصص الأنبياء',
      subtitle: 'السيرة كاملة بالأدلة',
      detail: 'القصة كما وردت في الكتاب والسنة، مع مواضعها من القرآن',
    ),
    (
      icon: '📜',
      title: 'التفسير',
      subtitle: 'أكثر من مفسّر لكل سورة',
      detail: 'تختار السورة، ثم تختار من تسمع له تفسيرها',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('الدروس'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('التعاليم',
                style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'كل درس مبنيّ على آيات المصحف وأحاديث الكتب المرفقة بالتطبيق، '
              'مع ذكر موضع كل نصّ.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
            ),
            const SizedBox(height: 12),
            for (final lesson in Lessons.all) ...[
              _lessonCard(context, lesson),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
            const Text('على القناة',
                style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: const Row(
                children: [
                  Icon(Icons.play_circle_outline,
                      color: AppColors.gold, size: 22),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'الحلقات تُنشر تباعاً على قناة التطبيق، وتظهر هنا فور رفعها.',
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.5),
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
                  child:
                      Text(lesson.icon, style: const TextStyle(fontSize: 21))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lesson.title,
                      style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(lesson.summary,
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 11.5)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _card(
      ({String icon, String title, String subtitle, String detail}) lesson) {
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
                    child:
                        Text(lesson.icon, style: const TextStyle(fontSize: 24))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson.title,
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(lesson.subtitle,
                        style: const TextStyle(
                            color: AppColors.textMuted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: const Text('قريباً',
                    style: TextStyle(color: AppColors.textGold, fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(lesson.detail,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}
