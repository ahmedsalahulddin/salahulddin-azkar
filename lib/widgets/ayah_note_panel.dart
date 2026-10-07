import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/ayah_notes_data.dart';
import '../l10n/strings.dart';

/// One book's note on an ayah — أسباب النزول or الإعراب — in a card that
/// opens and closes. Says so plainly when the book has nothing on the ayah.
class AyahNotePanel extends StatelessWidget {
  final AyahNoteKind kind;
  final int surah;
  final int ayah;
  final bool initiallyExpanded;

  const AyahNotePanel({
    super.key,
    required this.kind,
    required this.surah,
    required this.ayah,
    this.initiallyExpanded = false,
  });

  IconData get _icon => switch (kind) {
    AyahNoteKind.asbab => Icons.history_edu_rounded,
    AyahNoteKind.irab => Icons.spellcheck_rounded,
  };

  String get _title => switch (kind) {
    AyahNoteKind.asbab => t('notes.asbab'),
    AyahNoteKind.irab => t('notes.irab'),
  };

  String get _none => switch (kind) {
    AyahNoteKind.asbab => t('notes.asbabNone'),
    AyahNoteKind.irab => t('notes.irabNone'),
  };

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AyahNotesService.forAyah(kind, surah, ayah),
      builder: (context, snap) {
        final text = snap.data;
        final loading = snap.connectionState != ConnectionState.done;
        return Container(
          decoration: BoxDecoration(
            color: AppColors.blackCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: PageStorageKey('${kind.folder}-$surah-$ayah'),
              initiallyExpanded: initiallyExpanded && text != null,
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              iconColor: AppColors.gold,
              collapsedIconColor: AppColors.textMuted,
              leading: Icon(_icon, color: AppColors.gold, size: 18),
              title: Text(
                _title,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              subtitle: loading || text != null
                  ? null
                  : Text(
                      _none,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (text != null) ...[
                  SelectableText(
                    text,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${kind.book} — ${kind.author}',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
