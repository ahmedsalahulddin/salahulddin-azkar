import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';
import '../services/notification_service.dart';

/// Explains why the adhan needs Android's «Alarms & reminders» permission
/// and offers to open that page. True when exact alarms are allowed after.
Future<bool> offerExactAlarm(BuildContext context) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: AppLocale.direction,
      child: AlertDialog(
        backgroundColor: AppColors.blackCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.goldBorder),
        ),
        title: Text(
          t('adh.exactTitle'),
          style: const TextStyle(color: AppColors.gold, fontSize: 17),
        ),
        content: Text(
          t('adh.exactBody'),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.6,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              t('adh.laterButton'),
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t('adh.exactButton'),
              style: const TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    ),
  );
  if (go != true) return false;
  return NotificationService.requestExactAlarms();
}
