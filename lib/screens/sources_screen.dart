import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/sources.dart';
import '../l10n/strings.dart';

/// Whose work this app is carrying.
///
/// Not a legal notice and not fine print at the bottom of a settings page: a
/// reader trusting a text has a right to know whose text it is, and the people
/// who made it have a right to be named where the reader can see it.
class SourcesScreen extends StatelessWidget {
  const SourcesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(t('lib2.sourcesAndRightsTitle')),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              t('lib2.sourcesIntroText'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 18),
            for (final kind in SourceKind.values) ...[
              _heading(kind.label),
              for (final source in Sources.of(kind)) _card(source),
              const SizedBox(height: 14),
            ],
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _heading(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      label,
      style: const TextStyle(
        color: AppColors.gold,
        fontSize: 15,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _card(AppSource source) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            source.title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            source.holder,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          if (source.detail != null) ...[
            const SizedBox(height: 3),
            Text(
              source.detail!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                height: 1.6,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: _standing(source.standing),
          ),
        ],
      ),
    );
  }

  Widget _standing(Standing standing) {
    // The two that need nothing from anyone read in the app's own gold; the
    // two that rest on someone else's goodwill are marked apart, so the list
    // says at a glance where the app is standing on its own feet.
    final owed = standing == Standing.permission || standing == Standing.hosted;
    final tint = owed ? AppColors.textGold : AppColors.gold;

    return Tooltip(
      message: standing.note,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: owed ? Colors.transparent : AppColors.goldMuted,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.goldBorder),
        ),
        child: Text(
          standing.label,
          style: TextStyle(color: tint, fontSize: 10.5),
        ),
      ),
    );
  }

  Widget _footer() => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.goldMuted,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.goldBorder),
    ),
    child: Text(
      t('lib2.sourcesFooterText'),
      style: const TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        height: 1.9,
      ),
    ),
  );
}
