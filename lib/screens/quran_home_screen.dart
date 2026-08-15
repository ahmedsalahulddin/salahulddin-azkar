import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/quran_data.dart';
import '../services/storage_service.dart';
import 'memorisation_test_screen.dart';
import 'mushaf_screen.dart';
import 'quran_screen.dart';

/// Entry point for the Quran section: pick how you want to read.
///
/// تدبّر — verse by verse, with tafsir and recitation per ayah.
/// قراءة — the Mushaf page as it is printed, swiped page by page.
class QuranHomeScreen extends StatefulWidget {
  const QuranHomeScreen({super.key});

  @override
  State<QuranHomeScreen> createState() => _QuranHomeScreenState();
}

class _QuranHomeScreenState extends State<QuranHomeScreen> {
  int? _lastPage;
  String? _lastSurahName;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final page = await StorageService.getLastMushafPage();
    final surah = await StorageService.getLastSurah();
    String? name;
    if (surah != null) {
      final index = await QuranService.index();
      name = index.where((s) => s.number == surah).firstOrNull?.name;
    }
    if (!mounted) return;
    setState(() {
      _lastPage = page;
      _lastSurahName = name;
    });
  }

  Future<void> _openTadabbur() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QuranScreen()),
    );
    _loadProgress();
  }

  Future<void> _openMushaf() async {
    final page = await StorageService.getLastMushafPage() ?? 1;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MushafScreen(initialPage: page)),
    );
    _loadProgress();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: const Text('القرآن الكريم'),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'كيف تحب أن تقرأ؟',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 18),

              _modeCard(
                icon: '🕌',
                title: 'تلاوة وتدبّر',
                subtitle: 'آية آية، مع التفسير والتلاوة',
                details: const [
                  'التفسير الميسّر لكل آية',
                  'استمع للآية بصوت ستة قرّاء',
                  'بحث ونسخ ومواضع السجود',
                ],
                progress: _lastSurahName == null
                    ? null
                    : 'آخر قراءة: سورة $_lastSurahName',
                onTap: _openTadabbur,
              ),
              const SizedBox(height: 14),

              _modeCard(
                icon: '📖',
                title: 'القرآن الكريم',
                subtitle: 'صفحات',
                details: const [
                  'الـ ٦٠٤ صفحة بترتيب مصحف المدينة',
                  'اسحب لتقليب الصفحات',
                  'رقم الجزء والصفحة أمامك دائماً',
                ],
                progress: _lastPage == null
                    ? null
                    : 'آخر صفحة: ${QuranService.toArabicDigits(_lastPage!)}',
                onTap: _openMushaf,
                highlighted: true,
              ),
              const SizedBox(height: 14),

              _modeCard(
                icon: '🧠',
                title: 'اختبار الحفظ',
                subtitle: 'اختبر نفسك آية آية',
                details: const [
                  'ثلاثة مستويات — من إخفاء كلمة إلى الآية كاملة',
                  'اكشف بعد الاسترجاع وسجّل نتيجتك',
                  'نتيجة بالنسبة المئوية في نهاية السورة',
                ],
                onTap: _openMemorisationTest,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openMemorisationTest() => openMemorisationPicker(context);

  Widget _modeCard({
    required String icon,
    required String title,
    required String subtitle,
    required List<String> details,
    required VoidCallback onTap,
    String? progress,
    bool highlighted = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: highlighted
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.navyLight, AppColors.navy],
                )
              : null,
          color: highlighted ? null : AppColors.blackCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: highlighted ? AppColors.gold : AppColors.goldBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: AppColors.goldMuted,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.goldBorder),
                  ),
                  child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 26))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 21,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_left,
                    color: AppColors.textMuted, size: 22),
              ],
            ),
            const SizedBox(height: 14),
            for (final d in details)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  children: [
                    const Text('✦',
                        style: TextStyle(
                            color: AppColors.goldDark, fontSize: 11)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(d,
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            if (progress != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark,
                        color: AppColors.gold, size: 14),
                    const SizedBox(width: 6),
                    Text(progress,
                        style: const TextStyle(
                            color: AppColors.textGold, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
