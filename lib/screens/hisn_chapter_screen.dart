import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../data/hisn_data.dart';
import '../data/quran_data.dart' show QuranService;
import '../services/favourites.dart';
import '../widgets/bilingual_text.dart';
import '../widgets/dhikr_audio.dart';
import '../widgets/dhikr_text.dart';
import '../widgets/favourite_star.dart';
import '../widgets/speed_button.dart';

/// Reads one chapter, with a tap-to-count tracker for adhkar said more than
/// once so the reader does not have to keep count in their head.
class HisnChapterScreen extends StatefulWidget {
  final HisnChapter chapter;

  const HisnChapterScreen({super.key, required this.chapter});

  @override
  State<HisnChapterScreen> createState() => _HisnChapterScreenState();
}

class _HisnChapterScreenState extends State<HisnChapterScreen> {
  /// dhikr number -> times said so far. Deliberately not persisted: a session
  /// of adhkar is meant to start fresh.
  final _counts = <int, int>{};

  final _audio = DhikrAudioController();

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  int _countFor(HisnDhikr d) => _counts[d.number] ?? 0;
  bool _isDone(HisnDhikr d) => _countFor(d) >= d.repeat;

  void _tap(HisnDhikr d) {
    if (_isDone(d)) return;
    final next = _countFor(d) + 1;
    setState(() => _counts[d.number] = next);
    HapticFeedback.lightImpact();
    if (next >= d.repeat) HapticFeedback.mediumImpact();
  }

  void _resetAll() {
    setState(_counts.clear);
    HapticFeedback.mediumImpact();
  }

  Future<void> _copy(HisnDhikr d) async {
    await Clipboard.setData(ClipboardData(
      text: '${d.text}\n\n[${widget.chapter.title} — ${HisnService.attribution}]',
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الذكر', textDirection: TextDirection.rtl),
        backgroundColor: AppColors.emerald,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chapter = widget.chapter;
    final done = chapter.items.where(_isDone).length;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: BilingualText(chapter.displayTitle,
              style: const TextStyle(color: AppColors.gold, fontSize: 15),
              maxLines: 2),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            const SpeedButton(showLabel: false),
            if (_counts.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _resetAll,
                tooltip: 'إعادة العد',
              ),
          ],
        ),
        body: Column(
          children: [
            // Progress across the chapter
            if (chapter.items.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${chapter.items.length} أذكار',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12)),
                        Text('أتممت $done',
                            style: const TextStyle(
                                color: AppColors.textGold, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: done / chapter.items.length,
                        backgroundColor: AppColors.blackSurface,
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.gold),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                itemCount: chapter.items.length + 1,
                itemBuilder: (context, i) {
                  if (i == chapter.items.length) return _attribution();
                  return _dhikrCard(chapter.items[i]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dhikrCard(HisnDhikr d) {
    final count = _countFor(d);
    final done = _isDone(d);

    return GestureDetector(
      onTap: () => _tap(d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: done ? AppColors.emeraldMuted : AppColors.blackCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: done ? AppColors.emeraldLight : AppColors.goldBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DhikrText(
              arabic: d.text,
              english: d.english,
              fontSize: 19,
              color: done ? AppColors.textSecondary : AppColors.textPrimary,
              textAlign: TextAlign.justify,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                // Repeat / progress badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: done ? AppColors.emerald : AppColors.goldMuted,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: done ? AppColors.emeraldLight : AppColors.goldBorder,
                    ),
                  ),
                  child: Text(
                    done
                        ? '✓ تمّ'
                        : d.repeat == 1
                            ? 'مرة واحدة'
                            : '${QuranService.toArabicDigits(count)} / ${QuranService.toArabicDigits(d.repeat)}',
                    style: TextStyle(
                      color: done ? AppColors.white : AppColors.textGold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                DhikrListenButton(dhikr: d, controller: _audio),
                const SizedBox(width: 4),
                // Every dhikr in the section can be kept, not only the seven
                // categories that once had the star to themselves.
                FavouriteStar(
                  id: Favourites.hisnId(widget.chapter.id, d.number),
                  size: 19,
                ),
                GestureDetector(
                  onTap: () => _copy(d),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child:
                        Icon(Icons.copy, color: AppColors.textMuted, size: 17),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _attribution() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(
          HisnService.attribution,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
        ),
      );
}
