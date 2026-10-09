import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/gharib_data.dart';
import '../l10n/strings.dart';

/// معاني الكلمات: each unusual word of the ayah in the mushaf's script, with
/// its meaning beside it. Shown straight away, with nothing to choose first.
class GharibPanel extends StatelessWidget {
  final int surah;
  final int ayah;

  const GharibPanel({super.key, required this.surah, required this.ayah});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.menu_book_rounded,
                color: AppColors.gold,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                t('gharib.title'),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<GharibEntry>>(
            future: GharibService.forAyah(surah, ayah),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(
                    color: AppColors.gold,
                    backgroundColor: AppColors.goldMuted,
                  ),
                );
              }
              final entries = snap.data!;
              if (entries.isEmpty) {
                return Text(
                  t('gharib.none'),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final e in entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text.rich(
                        textDirection: TextDirection.rtl,
                        TextSpan(
                          children: [
                            TextSpan(
                              text: e.word,
                              style: const TextStyle(
                                fontFamily: 'AmiriQuran',
                                color: AppColors.textGold,
                                fontSize: 18,
                                height: 1.9,
                              ),
                            ),
                            const TextSpan(
                              text: ' : ',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                            TextSpan(
                              text: e.meaning,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                height: 1.7,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 4),
          const Text(
            '${GharibService.source} — ${GharibService.publisher}',
            style: TextStyle(color: AppColors.textMuted, fontSize: 10.5),
          ),
        ],
      ),
    );
  }
}
