import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../data/hisn_data.dart';
import '../data/quran_data.dart' show QuranService;
import '../data/umrah_data.dart';
import '../services/favourites.dart';
import '../widgets/bilingual_text.dart';
import '../widgets/dhikr_audio.dart';
import '../widgets/dhikr_text.dart';
import '../widgets/favourite_star.dart';

/// The Umrah supplications, walked through in the order of the rites.
///
/// Each stage opens to show its duas inline: on a pilgrimage the reader wants
/// the words in front of them, not another list to tap through.
class UmrahScreen extends StatefulWidget {
  const UmrahScreen({super.key});

  @override
  State<UmrahScreen> createState() => _UmrahScreenState();
}

class _UmrahScreenState extends State<UmrahScreen> {
  List<(UmrahStage, List<HisnChapter>)>? _stages;
  int _total = 0;

  /// Stages start closed except the first, so the whole rite is visible at once.
  final _expanded = <int>{0};

  final _audio = DhikrAudioController();

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stages = await UmrahGuide.load();
    final total = await UmrahGuide.totalDuas();
    if (!mounted) return;
    setState(() {
      _stages = stages;
      _total = total;
    });
  }

  Future<void> _copy(HisnDhikr dhikr, String chapterTitle) async {
    await Clipboard.setData(ClipboardData(
      text: '${dhikr.text}\n\n[$chapterTitle — ${UmrahGuide.attribution}]',
    ));
    if (!mounted) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم نسخ الدعاء', textDirection: TextDirection.rtl),
        backgroundColor: AppColors.emerald,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stages = _stages;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('أدعية العمرة'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: stages == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold))
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                itemCount: stages.length + 2,
                itemBuilder: (context, i) {
                  if (i == 0) return _intro();
                  if (i == stages.length + 1) return _footer();
                  final (stage, chapters) = stages[i - 1];
                  return _stageCard(i - 1, stage, chapters);
                },
              ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyLight, AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Column(
        children: [
          const Text('🕋', style: TextStyle(fontSize: 34)),
          const SizedBox(height: 8),
          const Text('أدعية العمرة',
              style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(
            'مرتّبة على خطوات النسك — ${QuranService.toArabicDigits(_total)} دعاءً',
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _stageCard(int index, UmrahStage stage, List<HisnChapter> chapters) {
    final open = _expanded.contains(index);
    final count = chapters.fold<int>(0, (s, c) => s + c.items.length);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: open ? AppColors.gold : AppColors.goldBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onTap: () => setState(() {
              open ? _expanded.remove(index) : _expanded.add(index);
            }),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  // Step number, so the order of the rite is obvious.
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.goldMuted,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.goldBorder),
                    ),
                    child: Center(
                      child: Text(QuranService.toArabicDigits(index + 1),
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(stage.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(stage.title,
                            style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('${QuranService.toArabicDigits(count)} دعاء',
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textMuted, size: 22),
                ],
              ),
            ),
          ),
          if (open) ...[
            Container(
              width: double.infinity,
              color: AppColors.blackSurface,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Text(stage.guidance,
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12, height: 1.5)),
            ),
            for (final chapter in chapters) ..._chapterBlock(chapter),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  List<Widget> _chapterBlock(HisnChapter chapter) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
        child: BilingualText(chapter.displayTitle,
            textAlign: TextAlign.right,
            maxLines: 2,
            style: const TextStyle(
                color: AppColors.textGold,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ),
      for (final dhikr in chapter.items)
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.black,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.goldBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DhikrText(
                arabic: dhikr.text,
                english: dhikr.english,
                fontSize: 18,
                color: AppColors.textPrimary,
                textAlign: TextAlign.justify,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (dhikr.repeat > 1)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.goldMuted,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.goldBorder),
                      ),
                      child: Text(
                          '${QuranService.toArabicDigits(dhikr.repeat)} مرات',
                          style: const TextStyle(
                              color: AppColors.textGold,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  const Spacer(),
                  DhikrListenButton(dhikr: dhikr, controller: _audio),
                  const SizedBox(width: 4),
                  FavouriteStar(
                    id: Favourites.hisnId(chapter.id, dhikr.number),
                    size: 18,
                  ),
                  GestureDetector(
                    onTap: () => _copy(dhikr, chapter.title),
                    behavior: HitTestBehavior.opaque,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.copy,
                          color: AppColors.textMuted, size: 17),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
    ];
  }

  Widget _footer() => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(UmrahGuide.attribution,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
      );
}
