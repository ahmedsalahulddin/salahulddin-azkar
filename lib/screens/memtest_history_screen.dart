import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/memorisation.dart' show TestMode;
import '../data/quran_data.dart';
import '../l10n/strings.dart';
import '../services/auth_service.dart';
import '../services/tahfeez_service.dart';
import 'tahfeez/tahfeez_widgets.dart';

/// Every Memory Test run one reader has saved, newest first — the reader's
/// own history when [studentId] is left out, or (when a related teacher
/// opens it from the student's progress screen) that student's history,
/// exactly as [TahfeezService.memtestResultsOf]'s RLS already allows.
class MemtestHistoryScreen extends StatefulWidget {
  final String? studentId;

  const MemtestHistoryScreen({super.key, this.studentId});

  @override
  State<MemtestHistoryScreen> createState() => _MemtestHistoryScreenState();
}

class _MemtestHistoryScreenState extends State<MemtestHistoryScreen> {
  List<MemtestResult> _results = const [];
  bool _loading = true;

  String get _studentId => widget.studentId ?? AuthService.user.value!.id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await TahfeezService.memtestResultsOf(_studentId);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNote(context, describeError(e), error: true);
    }
  }

  EvalGrade _gradeOf(int score) {
    if (score >= 90) return EvalGrade.excellent;
    if (score >= 75) return EvalGrade.veryGood;
    if (score >= 60) return EvalGrade.good;
    return EvalGrade.redo;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: tahfeezDirection(),
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('misc.memtestHistoryTitle')),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _results.isEmpty
            ? EmptyNote(icon: Icons.quiz, text: t('misc.noMemtestResultsYet'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _results.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _card(_results[i]),
              ),
      ),
    );
  }

  Widget _card(MemtestResult r) {
    final grade = _gradeOf(r.scorePercent);
    final modeLabel = TestMode.values
        .firstWhere((m) => m.name == r.mode, orElse: () => TestMode.complete)
        .label;

    return TahfeezCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: AppColors.gold,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      formatDate(r.createdAt),
                      style: const TextStyle(
                        color: AppColors.textGold,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${t('misc.surahPrefix')} ${r.surahName} — $modeLabel',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  t('misc.rememberedCountOf')
                      .replaceAll(
                        '{correct}',
                        QuranService.toArabicDigits(r.correctCount),
                      )
                      .replaceAll(
                        '{total}',
                        QuranService.toArabicDigits(r.questionCount),
                      ),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '%${QuranService.toArabicDigits(r.scorePercent)}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: gradeColor(grade).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  gradeLabel(grade),
                  style: TextStyle(
                    color: gradeColor(grade),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
