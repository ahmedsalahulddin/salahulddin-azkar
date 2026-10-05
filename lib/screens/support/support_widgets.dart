import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/support_service.dart';

String categoryLabel(SupportCategory c) => t('support.cat.${c.name}');

IconData categoryIcon(SupportCategory c) => switch (c) {
  SupportCategory.edit => Icons.edit_note,
  SupportCategory.teacher => Icons.school_outlined,
  SupportCategory.problem => Icons.report_problem_outlined,
  SupportCategory.suggestion => Icons.lightbulb_outline,
  SupportCategory.translation => Icons.translate,
  SupportCategory.contact => Icons.mail_outline,
  SupportCategory.other => Icons.chat_bubble_outline,
};

/// Today shows the time; earlier days show the date.
String shortWhen(DateTime at) {
  final local = at.toLocal();
  final now = DateTime.now();
  final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final m = local.minute.toString().padLeft(2, '0');
  final time = '$h:$m ${local.hour >= 12 ? t('account.pm') : t('account.am')}';
  if (local.year == now.year &&
      local.month == now.month &&
      local.day == now.day) {
    return time;
  }
  return '${local.day}/${local.month}/${local.year}';
}

/// "Solved" in green or "Open" in gold, as a small pill.
class StatusPill extends StatelessWidget {
  final bool resolved;
  const StatusPill({super.key, required this.resolved});

  @override
  Widget build(BuildContext context) {
    final color = resolved ? AppColors.success : AppColors.goldLight;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            resolved ? Icons.check_circle : Icons.schedule,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            resolved ? t('support.resolved') : t('support.open'),
            style: TextStyle(color: color, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
