import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// The lessons shelf: prophet stories and tafsir, meant to play from the
/// channel once it exists.
///
/// The cards are listed before the videos are, deliberately — the shape of the
/// section is settled here, and each card says plainly that its lessons are not
/// up yet rather than opening onto nothing.
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
