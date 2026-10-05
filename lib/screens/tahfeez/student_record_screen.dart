import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../data/quran_data.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
import 'tahfeez_widgets.dart';

/// One student's record with this teacher: who they are (name and code),
/// then each circle they were assessed in with its total points. A circle
/// opens every session's assessment in it.
class StudentRecordScreen extends StatelessWidget {
  final TeacherStudent student;
  final List<Halaqa> halaqat;
  final List<TahfeezSession> sessions;

  /// This student's assessments, in this teacher's sessions.
  final List<Evaluation> evaluations;

  /// Circles the student is in right now.
  final Set<String> currentHalaqat;

  const StudentRecordScreen({
    super.key,
    required this.student,
    required this.halaqat,
    required this.sessions,
    required this.evaluations,
    required this.currentHalaqat,
  });

  @override
  Widget build(BuildContext context) {
    final halaqaOfSession = {for (final s in sessions) s.id: s.halaqaId};
    final byHalaqa = <String, List<Evaluation>>{};
    for (final e in evaluations) {
      final h = halaqaOfSession[e.sessionId];
      if (h != null) byHalaqa.putIfAbsent(h, () => []).add(e);
    }
    final shown = [
      for (final h in halaqat)
        if (byHalaqa.containsKey(h.id) || currentHalaqat.contains(h.id)) h,
    ];
    final total = evaluations.fold<int>(0, (a, e) => a + e.score);

    return Directionality(
      textDirection: tahfeezDirection(),
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(student.name),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _header(total),
            const SizedBox(height: 16),
            SectionTitle(t('tahfeez.recordByHalaqa')),
            if (shown.isEmpty)
              EmptyNote(icon: Icons.timeline, text: t('tahfeez.noEvaluations'))
            else
              for (final h in shown) ...[
                _halaqaCard(context, h, byHalaqa[h.id] ?? const []),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }

  Widget _header(int total) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyLight, AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.goldMuted,
            backgroundImage: student.photoUrl != null
                ? NetworkImage(student.photoUrl!)
                : null,
            child: student.photoUrl == null
                ? const Icon(Icons.person, color: AppColors.gold, size: 26)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (student.code != null)
                  Text(
                    '${t('tahfeez.studentCode')} ${student.code}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '$total',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                t('tahfeez.totalPoints'),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _halaqaCard(BuildContext context, Halaqa h, List<Evaluation> evals) {
    final total = evals.fold<int>(0, (a, e) => a + e.score);
    final max = evals.fold<int>(0, (a, e) => a + e.maxScore);
    final now = currentHalaqat.contains(h.id);
    return TahfeezCard(
      onTap: evals.isEmpty
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => HalaqaRecordScreen(
                  student: student,
                  halaqa: h,
                  sessions: sessions,
                  evaluations: evals,
                ),
              ),
            ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.goldMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.menu_book_rounded, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        h.name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (now) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          t('tahfeez.currentlyIn'),
                          style: const TextStyle(
                            color: AppColors.success,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${evals.length} ${t('tahfeez.evaluationsCount')}'
                  '${max > 0 ? ' · $total ${t('tahfeez.outOf')} $max' : ''}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$total',
            style: const TextStyle(
              color: AppColors.gold,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          if (evals.isNotEmpty)
            Icon(tahfeezChevron, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

/// Every assessment one student got in one circle, newest first, each with
/// its grades and the points it earned.
class HalaqaRecordScreen extends StatefulWidget {
  final TeacherStudent student;
  final Halaqa halaqa;
  final List<TahfeezSession> sessions;
  final List<Evaluation> evaluations;

  const HalaqaRecordScreen({
    super.key,
    required this.student,
    required this.halaqa,
    required this.sessions,
    required this.evaluations,
  });

  @override
  State<HalaqaRecordScreen> createState() => _HalaqaRecordScreenState();
}

class _HalaqaRecordScreenState extends State<HalaqaRecordScreen> {
  List<SurahInfo> _surahs = const [];

  @override
  void initState() {
    super.initState();
    QuranService.index().then((s) {
      if (mounted) setState(() => _surahs = s);
    });
  }

  TahfeezSession? _sessionOf(String id) {
    for (final s in widget.sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final evals = [...widget.evaluations]
      ..sort((a, b) => b.date.compareTo(a.date));
    final total = evals.fold<int>(0, (a, e) => a + e.score);
    return Directionality(
      textDirection: tahfeezDirection(),
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.student.name, style: const TextStyle(fontSize: 16)),
              Text(
                '${widget.halaqa.name} · $total ${t('tahfeez.points')}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: evals.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _card(evals[i]),
        ),
      ),
    );
  }

  Widget _card(Evaluation e) {
    final s = _sessionOf(e.sessionId);
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
                  [
                    formatDate(e.date),
                    if (s != null)
                      '${formatTime(s.start)} – ${formatTime(s.end)}',
                  ].join(' · '),
                  style: const TextStyle(
                    color: AppColors.textGold,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${e.score} ${t('tahfeez.outOf')} ${e.maxScore}',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.only(bottom: 8),
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
                if (_surahs.isNotEmpty)
                  Text(
                    rangeLabel(p, _surahs),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                if (p.note != null && p.note!.isNotEmpty)
                  Text(
                    p.note!,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
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
              '${gradeLabel(p.grade)} · ${p.grade.score}',
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
