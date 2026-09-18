import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../data/quran_data.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';

String weekdayName(int weekday) => t('tahfeez.day.$weekday');

/// Dart's DateTime counts Monday = 1 … Sunday = 7; the table counts from
/// Sunday = 0 like Postgres.
int weekdayOf(DateTime d) => d.weekday % 7;

String formatTime(TimeOfDay tod) {
  final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
  final m = tod.minute.toString().padLeft(2, '0');
  final suffix = tod.period == DayPeriod.am ? 'ص' : 'م';
  return '$h:$m $suffix';
}

String formatDate(DateTime d) =>
    '${weekdayName(weekdayOf(d))} ${d.day}/${d.month}/${d.year}';

String gradeLabel(EvalGrade g) => t('tahfeez.grade.${g.name}');

Color gradeColor(EvalGrade g) => switch (g) {
  EvalGrade.excellent => AppColors.success,
  EvalGrade.veryGood => AppColors.emeraldLight,
  EvalGrade.good => AppColors.goldLight,
  EvalGrade.redo => AppColors.error,
};

enum EvalPointKind { review, newHifz, tafsir }

String pointLabel(EvalPointKind k) => t('tahfeez.point.${k.name}');

IconData pointIcon(EvalPointKind k) => switch (k) {
  EvalPointKind.review => Icons.replay_rounded,
  EvalPointKind.newHifz => Icons.auto_stories_rounded,
  EvalPointKind.tafsir => Icons.lightbulb_outline_rounded,
};

EvalPoint? pointOf(Evaluation e, EvalPointKind k) => switch (k) {
  EvalPointKind.review => e.review,
  EvalPointKind.newHifz => e.newHifz,
  EvalPointKind.tafsir => e.tafsir,
};

/// "البقرة ١ – آل عمران ١٠", using whichever surah list has loaded.
String rangeLabel(EvalPoint p, List<SurahInfo> surahs) {
  String name(int n) => surahs.isEmpty
      ? '$n'
      : surahs
            .firstWhere((s) => s.number == n, orElse: () => surahs.first)
            .name;
  if (p.fromSurah == p.toSurah) {
    return '${name(p.fromSurah)} ${p.fromAyah}–${p.toAyah}';
  }
  return '${name(p.fromSurah)} ${p.fromAyah} – ${name(p.toSurah)} ${p.toAyah}';
}

class TahfeezCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  const TahfeezCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: box,
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionTitle(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4, top: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textGold,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class GoldButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool busy;

  const GoldButton({
    super.key,
    required this.label,
    this.icon,
    this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.black,
          disabledBackgroundColor: AppColors.goldDark,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.black,
                ),
              )
            : Icon(icon ?? Icons.check, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}

class EmptyNote extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? hint;

  const EmptyNote({
    super.key,
    required this.icon,
    required this.text,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.textMuted),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String message,
  String? confirmLabel,
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.blackCard,
        content: Text(
          message,
          style: const TextStyle(color: AppColors.textPrimary, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t('tahfeez.cancel'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel ?? t('tahfeez.delete'),
              style: TextStyle(
                color: destructive ? AppColors.error : AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return ok == true;
}

/// One line of text from the reader, or null if they backed out.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  required String hint,
  String initial = '',
  String? confirmLabel,
  String? subtitle,
  int maxLines = 1,
  TextCapitalization capitalization = TextCapitalization.none,
}) async {
  final controller = TextEditingController(text: initial);
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.blackCard,
        title: Text(
          title,
          style: const TextStyle(color: AppColors.gold, fontSize: 17),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subtitle != null) ...[
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: maxLines,
              textCapitalization: capitalization,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textMuted),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.goldBorder),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: AppColors.gold),
                ),
              ),
              onSubmitted: maxLines == 1
                  ? (v) => Navigator.pop(ctx, v.trim())
                  : null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              t('tahfeez.cancel'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(
              confirmLabel ?? t('tahfeez.save'),
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  controller.dispose();
  return result;
}

void showNote(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text, textDirection: TextDirection.rtl),
      backgroundColor: error ? AppColors.error : AppColors.emerald,
    ),
  );
}

/// Words a server rule for the reader; anything unexpected reads as a
/// connection problem, which is what it almost always is.
String describeError(Object e) {
  if (e is TahfeezException) {
    return switch (e.code) {
      'max_sessions_per_day' => t('tahfeez.sessionLimit'),
      'no_such_code' => t('tahfeez.noSuchCode'),
      'own_halaqa' => t('tahfeez.ownHalaqa'),
      'blocked' => t('tahfeez.blockedError'),
      'gender_mismatch' => t('tahfeez.genderMismatch'),
      'network' => t('tahfeez.loadFailed'),
      _ => t('tahfeez.saveFailed'),
    };
  }
  return t('tahfeez.loadFailed');
}
