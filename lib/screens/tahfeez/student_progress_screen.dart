import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../data/quran_data.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
import '../memtest_history_screen.dart';
import 'tahfeez_widgets.dart';

/// Every assessment one student has received, newest first — the same
/// screen whether the student is reading their own record or the teacher
/// is reading it about them.
class StudentProgressScreen extends StatefulWidget {
  final String studentId;
  final String title;
  final List<TahfeezSession> sessions;
  final List<Halaqa> halaqat;

  const StudentProgressScreen({
    super.key,
    required this.studentId,
    required this.title,
    required this.sessions,
    required this.halaqat,
  });

  @override
  State<StudentProgressScreen> createState() => _StudentProgressScreenState();
}

class _StudentProgressScreenState extends State<StudentProgressScreen> {
  List<Evaluation> _evaluations = const [];
  List<SurahInfo> _surahs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        TahfeezService.evaluationsOf(widget.studentId),
        QuranService.index(),
      ]);
      if (!mounted) return;
      setState(() {
        _evaluations = results[0] as List<Evaluation>;
        _surahs = results[1] as List<SurahInfo>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNote(context, describeError(e), error: true);
    }
  }

  String _halaqaNameOf(String sessionId) {
    for (final s in widget.sessions) {
      if (s.id == sessionId) {
        for (final h in widget.halaqat) {
          if (h.id == s.halaqaId) return h.name;
        }
      }
    }
    return '';
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
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: t('misc.viewMemtestHistory'),
              icon: const Icon(Icons.quiz_outlined),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      MemtestHistoryScreen(studentId: widget.studentId),
                ),
              ),
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _evaluations.isEmpty
            ? EmptyNote(icon: Icons.timeline, text: t('tahfeez.noEvaluations'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: _evaluations.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _card(_evaluations[i]),
              ),
      ),
    );
  }

  Widget _card(Evaluation e) {
    final halaqa = _halaqaNameOf(e.sessionId);
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  formatDate(e.date),
                  style: const TextStyle(
                    color: AppColors.textGold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (halaqa.isNotEmpty)
                Text(
                  halaqa,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const Divider(color: AppColors.goldBorder, height: 18),
          for (final k in EvalPointKind.values)
            if (pointOf(e, k) != null) _pointRow(k, pointOf(e, k)!),
        ],
      ),
    );
  }

  Widget _pointRow(EvalPointKind k, EvalPoint p) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(pointIcon(k), size: 18, color: AppColors.gold),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pointLabel(k),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rangeLabel(p, _surahs),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (p.note != null && p.note!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    p.note!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: gradeColor(p.grade).withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              gradeLabel(p.grade),
              style: TextStyle(
                color: gradeColor(p.grade),
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
