import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/lessons.dart';
import '../widgets/speak_button.dart';

/// One lesson: an opening text, then the points, each with what it rests on.
class LessonScreen extends StatelessWidget {
  final Lesson lesson;

  const LessonScreen({super.key, required this.lesson});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(lesson.title),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(lesson.summary,
                style: const TextStyle(
                    color: AppColors.textMuted, fontSize: 13)),
            if (lesson.opening != null) ...[
              const SizedBox(height: 14),
              _SourceCard(source: lesson.opening!, leading: true),
            ],
            const SizedBox(height: 18),
            for (var i = 0; i < lesson.points.length; i++) ...[
              _point(lesson.points[i], i + 1),
              const SizedBox(height: 14),
            ],
            const SizedBox(height: 8),
            const Text(
              'كل نصٍّ في هذا الدرس مقروء من مصحف التطبيق أو من كتبه، '
              'لا منقولاً هنا — فما تقرأه هو ما في المصدر حرفاً بحرف.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppColors.textMuted, fontSize: 11, height: 1.7),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _point(LessonPoint point, int number) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Center(
                  child: Text('$number',
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(point.title,
                      style: const TextStyle(
                          color: AppColors.gold,
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
                ),
              ),
              SpeakButton(
                id: '${lesson.id}:$number',
                text: '${point.title}. ${point.body}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(point.body,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 14, height: 1.9)),
          if (point.source != null) ...[
            const SizedBox(height: 12),
            _SourceCard(source: point.source!),
          ],
        ],
      ),
    );
  }
}

/// The verse or hadith a point rests on, read from the bundle when it paints.
class _SourceCard extends StatelessWidget {
  final LessonSource source;

  /// The opening source gets more room, being the lesson's own text.
  final bool leading;

  const _SourceCard({required this.source, this.leading = false});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ResolvedSource?>(
      future: Lessons.resolve(source),
      builder: (context, snapshot) {
        final resolved = snapshot.data;
        // A source that cannot be read is left out rather than replaced with an
        // apology; the lesson still reads.
        if (resolved == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.navyLight, AppColors.navy],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                resolved.text,
                textAlign: TextAlign.center,
                maxLines: leading ? 14 : 6,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'AmiriQuran',
                  color: AppColors.textPrimary,
                  fontSize: leading ? 16 : 15,
                  height: 2.0,
                ),
              ),
              const SizedBox(height: 8),
              Text(resolved.citation,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: AppColors.textGold, fontSize: 11)),
            ],
          ),
        );
      },
    );
  }
}
