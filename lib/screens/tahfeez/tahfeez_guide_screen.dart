import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/app_locale.dart';
import 'tahfeez_widgets.dart';

/// How the Tahfeez section works, step by step, for a teacher and for a
/// student. Pops `true` when the reader asks for the on-screen tour.
class TahfeezGuideScreen extends StatefulWidget {
  /// Opens on the teacher's steps when the reader is a teacher.
  final bool teacher;

  const TahfeezGuideScreen({super.key, this.teacher = false});

  @override
  State<TahfeezGuideScreen> createState() => _TahfeezGuideScreenState();
}

class _TahfeezGuideScreenState extends State<TahfeezGuideScreen> {
  late bool _teacher = widget.teacher;

  static const _teacherSteps = [
    (Icons.verified_user_outlined, 't1'),
    (Icons.event_available, 't2'),
    (Icons.add_circle_outline, 't3'),
    (Icons.calendar_month, 't4'),
    (Icons.person_add_alt_1, 't5'),
    (Icons.star_rate_rounded, 't6'),
    (Icons.leaderboard_outlined, 't7'),
    (Icons.visibility_outlined, 't8'),
  ];

  static const _studentSteps = [
    (Icons.login, 's1'),
    (Icons.person_search, 's2'),
    (Icons.send, 's3'),
    (Icons.school_outlined, 's4'),
    (Icons.menu_book_rounded, 's5'),
    (Icons.badge_outlined, 's6'),
  ];

  @override
  Widget build(BuildContext context) {
    final steps = _teacher ? _teacherSteps : _studentSteps;
    return Directionality(
      textDirection: tahfeezDirection(),
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('guide.title')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
          children: [
            _switch(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.touch_app_outlined, size: 18),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.gold,
                  side: const BorderSide(color: AppColors.gold),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                label: Text(t('guide.startTour')),
              ),
            ),
            const SizedBox(height: 14),
            for (final (i, (icon, key)) in steps.indexed) ...[
              _step(i + 1, icon, key),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://azkar.salahulddin.com/guide?lang=${AppLocale.code}',
                ),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(
                Icons.open_in_new,
                size: 16,
                color: AppColors.gold,
              ),
              label: Text(
                t('guide.fullGuide'),
                style: const TextStyle(color: AppColors.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switch() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.blackSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          for (final (teacher, label) in [
            (true, t('guide.forTeacher')),
            (false, t('guide.forStudent')),
          ])
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _teacher = teacher),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: teacher == _teacher
                        ? AppColors.gold
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: teacher == _teacher
                          ? AppColors.black
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: teacher == _teacher
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _step(int n, IconData icon, String key) {
    return TahfeezCard(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.gold,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$n',
              style: const TextStyle(
                color: AppColors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: AppColors.gold, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        t('guide.$key.title'),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  t('guide.$key.body'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
