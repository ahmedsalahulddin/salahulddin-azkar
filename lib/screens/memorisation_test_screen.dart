import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../constants/theme.dart';
import '../data/quran_data.dart';

const _mushafFont = 'AmiriQuran';

/// How much of each ayah is hidden during the drill.
enum TestDifficulty {
  easy('سهل', 'يُخفى آخر كلمة', 1),
  medium('متوسط', 'تُخفى آخر ثلاث كلمات', 3),
  hard('صعب', 'تُخفى الآية كلها', -1);

  final String label;
  final String hint;

  /// Words hidden from the end, or -1 for the whole ayah.
  final int hiddenWords;

  const TestDifficulty(this.label, this.hint, this.hiddenWords);
}

/// Hides part of each ayah and asks the reader to recall it before revealing.
///
/// Words are hidden from the end so the opening still cues recall — which is
/// how memorisation is actually checked, rather than blanking words at random.
class MemorisationTestScreen extends StatefulWidget {
  final SurahInfo info;

  const MemorisationTestScreen({super.key, required this.info});

  @override
  State<MemorisationTestScreen> createState() => _MemorisationTestScreenState();
}

class _MemorisationTestScreenState extends State<MemorisationTestScreen> {
  Surah? _surah;
  TestDifficulty _difficulty = TestDifficulty.medium;
  int _position = 0;
  bool _revealed = false;
  int _correct = 0;
  int _missed = 0;

  @override
  void initState() {
    super.initState();
    QuranService.surah(widget.info.number).then((s) {
      if (mounted) setState(() => _surah = s);
    });
  }

  Ayah get _ayah => _surah!.ayahs[_position];
  bool get _finished => _position >= _surah!.ayahs.length;

  /// Splits the ayah into the part left visible and the part to recall.
  (String visible, String hidden) _split(Ayah ayah) {
    if (_difficulty.hiddenWords < 0) return ('', ayah.text);

    final words = ayah.text.split(' ');
    final hide = _difficulty.hiddenWords.clamp(1, words.length - 1);
    if (words.length <= 1) return ('', ayah.text);

    return (
      words.sublist(0, words.length - hide).join(' '),
      words.sublist(words.length - hide).join(' '),
    );
  }

  void _answer({required bool remembered}) {
    HapticFeedback.lightImpact();
    setState(() {
      remembered ? _correct++ : _missed++;
      _position++;
      _revealed = false;
    });
  }

  void _restart() {
    setState(() {
      _position = 0;
      _correct = 0;
      _missed = 0;
      _revealed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final surah = _surah;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text('اختبار الحفظ — ${widget.info.name}',
              style: const TextStyle(fontSize: 16)),
        ),
        body: surah == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.gold))
            : _finished
                ? _results()
                : _question(),
      ),
    );
  }

  Widget _question() {
    final ayah = _ayah;
    final (visible, hidden) = _split(ayah);
    final total = _surah!.ayahs.length;

    return Column(
      children: [
        // Progress
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      'الآية ${QuranService.toArabicDigits(ayah.number)} من ${QuranService.toArabicDigits(total)}',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12)),
                  Text('✓ ${QuranService.toArabicDigits(_correct)}   ✗ ${QuranService.toArabicDigits(_missed)}',
                      style: const TextStyle(
                          color: AppColors.textGold, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: _position / total,
                  backgroundColor: AppColors.blackSurface,
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                  minHeight: 5,
                ),
              ),
            ],
          ),
        ),

        _difficultyPicker(),

        // The ayah, part of it withheld
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(20),
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
                  Text.rich(
                    TextSpan(children: [
                      if (visible.isNotEmpty)
                        TextSpan(
                          text: '$visible ',
                          style: const TextStyle(color: AppColors.textPrimary),
                        ),
                      TextSpan(
                        text: hidden,
                        style: TextStyle(
                          color: _revealed
                              ? AppColors.gold
                              : Colors.transparent,
                          backgroundColor: _revealed
                              ? Colors.transparent
                              : AppColors.blackSurface,
                          decoration: _revealed
                              ? TextDecoration.none
                              : TextDecoration.underline,
                          decorationColor: AppColors.goldBorder,
                        ),
                      ),
                    ]),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: _mushafFont,
                      fontSize: 24,
                      height: 2.2,
                    ),
                  ),
                  if (!_revealed) ...[
                    const SizedBox(height: 14),
                    Text(
                      _difficulty == TestDifficulty.hard
                          ? 'استرجع الآية كاملة ثم اكشف'
                          : 'أكمل الآية ثم اكشف',
                      style: const TextStyle(
                          color: AppColors.textMuted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: _revealed
              ? Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _answer(remembered: false),
                        icon: const Icon(Icons.close, size: 18),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        label: const Text('لم أتذكّر'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _answer(remembered: true),
                        icon: const Icon(Icons.check, size: 18),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        label: const Text('تذكّرتها'),
                      ),
                    ),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => setState(() => _revealed = true),
                    icon: const Icon(Icons.visibility, size: 18),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.goldDark,
                      foregroundColor: AppColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    label: const Text('اكشف'),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _difficultyPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final level in TestDifficulty.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: GestureDetector(
                  onTap: () => setState(() {
                    _difficulty = level;
                    _revealed = false;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(
                      color: _difficulty == level
                          ? AppColors.goldMuted
                          : AppColors.blackCard,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _difficulty == level
                              ? AppColors.gold
                              : AppColors.goldBorder),
                    ),
                    child: Column(
                      children: [
                        Text(level.label,
                            style: TextStyle(
                              color: _difficulty == level
                                  ? AppColors.gold
                                  : AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: _difficulty == level
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            )),
                        Text(level.hint,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _results() {
    final total = _correct + _missed;
    final score = total == 0 ? 0 : (_correct * 100 / total).round();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(score >= 80 ? '🌟' : '📖',
                style: const TextStyle(fontSize: 52)),
            const SizedBox(height: 14),
            Text('$score%',
                style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 40,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              'تذكّرت ${QuranService.toArabicDigits(_correct)} من ${QuranService.toArabicDigits(total)} آية',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              score >= 90
                  ? 'حفظ متقن — واصل المراجعة'
                  : score >= 60
                      ? 'قريب — راجع ما فاتك'
                      : 'يحتاج مراجعة قبل الاختبار مرة أخرى',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _restart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('أعد الاختبار'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.goldBorder),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                child: const Text('رجوع',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
