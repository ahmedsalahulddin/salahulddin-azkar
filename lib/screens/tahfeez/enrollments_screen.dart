import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/auth_service.dart';
import '../../services/tahfeez_service.dart';
import 'chat_screen.dart';
import 'student_record_screen.dart';
import 'tahfeez_widgets.dart';

/// A teacher's students in three views, switched at the top: the current
/// ones with their requests and terms; the current ones ranked by their
/// evaluation points; and everyone they have ever taught. A search box above
/// finds anyone by name or code, and a name opens that student's
/// record circle by circle.
class EnrollmentsScreen extends StatefulWidget {
  final List<TahfeezSession> sessions;
  final List<Halaqa> halaqat;

  /// Data to show instead of fetching — previews only.
  @visibleForTesting
  final List<Enrollment>? initialEnrollments;
  @visibleForTesting
  final List<TeacherStudent>? initialStudents;
  @visibleForTesting
  final List<Evaluation>? initialEvaluations;
  @visibleForTesting
  final List<HalaqaMember>? initialMembers;

  const EnrollmentsScreen({
    super.key,
    required this.sessions,
    required this.halaqat,
    this.initialEnrollments,
    this.initialStudents,
    this.initialEvaluations,
    this.initialMembers,
  });

  @override
  State<EnrollmentsScreen> createState() => _EnrollmentsScreenState();
}

enum _View { current, currentScores, allScores }

class _EnrollmentsScreenState extends State<EnrollmentsScreen> {
  List<Enrollment> _all = const [];
  Map<String, TeacherStudent> _students = const {};
  List<Evaluation> _evaluations = const [];
  List<HalaqaMember> _members = const [];
  bool _loading = true;
  String? _busyId;
  _View _view = _View.current;
  String _query = '';

  bool get _offline => widget.initialEnrollments != null;
  String get _me => AuthService.user.value!.id;

  List<Halaqa> get _taught =>
      widget.halaqat.where((h) => h.teacherId == _me).toList();

  late final Map<String, String> _halaqaOfSession = {
    for (final s in widget.sessions) s.id: s.halaqaId,
  };

  @override
  void initState() {
    super.initState();
    if (_offline) {
      _all = widget.initialEnrollments!;
      _students = {
        for (final s in widget.initialStudents ?? const <TeacherStudent>[])
          s.id: s,
      };
      _evaluations = widget.initialEvaluations ?? const [];
      _members = widget.initialMembers ?? const [];
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final taughtIds = _taught.map((h) => h.id).toSet();
      final sessionIds = [
        for (final s in widget.sessions)
          if (taughtIds.contains(s.halaqaId)) s.id,
      ];
      final results = await Future.wait([
        TahfeezService.enrollments(),
        TahfeezService.evaluationsInSessions(sessionIds),
        TahfeezService.membersOf(taughtIds.toList()),
        // Older servers may not have the code/email call yet.
        TahfeezService.teacherStudents().catchError(
          (_) => const <TeacherStudent>[],
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _all = (results[0] as List<Enrollment>)
            .where((e) => e.teacherId == _me)
            .toList();
        _evaluations = results[1] as List<Evaluation>;
        _members = results[2] as List<HalaqaMember>;
        _students = {
          for (final s in results[3] as List<TeacherStudent>) s.id: s,
        };
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNote(context, describeError(e), error: true);
    }
  }

  List<Enrollment> get _pending => _all.where((e) => e.isPending).toList();
  List<Enrollment> get _active => _all.where((e) => e.isActive).toList();
  List<Enrollment> get _expired => _all.where((e) => e.isExpired).toList();

  /// Circles a student is in right now.
  Set<String> _currentHalaqat(String studentId) => {
    for (final m in _members)
      if (m.studentId == studentId) m.halaqaId,
  };

  /// Points earned, in [halaqaIds] only when given.
  int _total(String studentId, {Set<String>? halaqaIds}) {
    var sum = 0;
    for (final e in _evaluations) {
      if (e.studentId != studentId) continue;
      final h = _halaqaOfSession[e.sessionId];
      if (halaqaIds != null && !halaqaIds.contains(h)) continue;
      sum += e.score;
    }
    return sum;
  }

  /// Name, code and email for anyone this teacher knows, from the records
  /// call, the enrolment's profile, or the circle membership.
  TeacherStudent _who(String id) {
    final known = _students[id];
    if (known != null) return known;
    for (final e in _all) {
      if (e.studentId == id && e.student != null) {
        return TeacherStudent(
          id: id,
          name: e.student!.displayName,
          code: e.student!.studentCode,
          photoUrl: e.student!.photoUrl,
        );
      }
    }
    return TeacherStudent(id: id, name: t('tahfeez.student'));
  }

  bool _matches(TeacherStudent s) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return s.name.toLowerCase().contains(q) ||
        (s.code?.toLowerCase().contains(q) ?? false);
  }

  Future<void> _run(Enrollment e, Future<void> Function() action) async {
    setState(() => _busyId = e.id);
    try {
      await action();
      await _load();
    } catch (err) {
      if (mounted) showNote(context, describeError(err), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _openRecord(TeacherStudent s) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StudentRecordScreen(
          student: s,
          halaqat: _taught,
          sessions: widget.sessions,
          evaluations: _evaluations.where((e) => e.studentId == s.id).toList(),
          currentHalaqat: _currentHalaqat(s.id),
        ),
      ),
    );
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
          title: Text(t('tahfeez.myStudents')),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: _search(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    child: _switch(),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.gold,
                      backgroundColor: AppColors.blackCard,
                      onRefresh: _offline ? () async {} : _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
                        children: switch (_view) {
                          _View.current => _currentView(),
                          _View.currentScores => _scoresView(current: true),
                          _View.allScores => _scoresView(current: false),
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _search() => TextField(
    onChanged: (v) => setState(() => _query = v),
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
    decoration: InputDecoration(
      hintText: t('tahfeez.searchStudents'),
      hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
      prefixIcon: const Icon(
        Icons.search,
        color: AppColors.textMuted,
        size: 20,
      ),
      isDense: true,
      filled: true,
      fillColor: AppColors.blackCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.goldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.goldBorder),
      ),
    ),
  );

  Widget _switch() {
    final items = [
      (_View.current, t('tahfeez.view.current')),
      (_View.currentScores, t('tahfeez.view.currentScores')),
      (_View.allScores, t('tahfeez.view.allScores')),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.blackSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          for (final (v, label) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _view = v),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    vertical: 9,
                    horizontal: 2,
                  ),
                  decoration: BoxDecoration(
                    color: v == _view ? AppColors.gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: TextStyle(
                      color: v == _view
                          ? AppColors.black
                          : AppColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.3,
                      fontWeight: v == _view
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _currentView() {
    bool shown(Enrollment e) => _matches(_who(e.studentId));
    final pending = _pending.where(shown).toList();
    final active = _active.where(shown).toList();
    final expired = _expired.where(shown).toList();
    if (_all.isEmpty) {
      return [
        EmptyNote(
          icon: Icons.groups_outlined,
          text: t('tahfeez.noEnrollments'),
        ),
      ];
    }
    return [
      if (pending.isNotEmpty) ...[
        SectionTitle('${t('tahfeez.pendingRequests')} (${pending.length})'),
        for (final e in pending) ...[_card(e), const SizedBox(height: 8)],
        const SizedBox(height: 12),
      ],
      SectionTitle('${t('tahfeez.activeStudents')} (${active.length})'),
      if (active.isEmpty)
        EmptyNote(icon: Icons.person_outline, text: t('tahfeez.noEnrollments'))
      else
        for (final e in active) ...[_card(e), const SizedBox(height: 8)],
      if (expired.isNotEmpty) ...[
        const SizedBox(height: 12),
        SectionTitle('${t('tahfeez.expiredStudents')} (${expired.length})'),
        for (final e in expired) ...[_card(e), const SizedBox(height: 8)],
      ],
    ];
  }

  /// Students with their points, highest first: the current ones counted
  /// in the circles they are in now, or everyone over all time.
  List<Widget> _scoresView({required bool current}) {
    final ids = <String>{
      if (current) ...[
        for (final e in _active) e.studentId,
        for (final m in _members) m.studentId,
      ] else ...[
        ..._students.keys,
        for (final e in _all)
          if (!e.isPending && e.status != EnrollmentStatus.rejected)
            e.studentId,
        for (final ev in _evaluations) ev.studentId,
      ],
    };
    final rows =
        [
          for (final id in ids)
            (
              _who(id),
              current ? _total(id, halaqaIds: _currentHalaqat(id)) : _total(id),
              _evaluations.where((e) => e.studentId == id).length,
            ),
        ].where((r) => _matches(r.$1)).toList()..sort(
          (a, b) => b.$2.compareTo(a.$2),
        );
    if (rows.isEmpty) {
      return [
        EmptyNote(
          icon: Icons.leaderboard_outlined,
          text: t('tahfeez.noScores'),
        ),
      ];
    }
    return [
      Text(
        current ? t('tahfeez.currentScoresSub') : t('tahfeez.allScoresSub'),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 10),
      for (final (i, (s, total, count)) in rows.indexed) ...[
        _scoreRow(i + 1, s, total, count),
        const SizedBox(height: 8),
      ],
    ];
  }

  Widget _scoreRow(int rank, TeacherStudent s, int total, int count) {
    return TahfeezCard(
      onTap: () => _openRecord(s),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: rank <= 3 ? AppColors.gold : AppColors.textMuted,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.goldMuted,
            backgroundImage: s.photoUrl != null
                ? NetworkImage(s.photoUrl!)
                : null,
            child: s.photoUrl == null
                ? const Icon(Icons.person, color: AppColors.gold, size: 18)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  [
                    if (s.code != null) s.code!,
                    '$count ${t('tahfeez.evaluationsCount')}',
                  ].join(' · '),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _scoreChip(total),
          Icon(tahfeezChevron, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _scoreChip(int total) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.goldMuted,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
    ),
    child: Text(
      '$total ${t('tahfeez.points')}',
      style: const TextStyle(
        color: AppColors.gold,
        fontSize: 12,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _card(Enrollment e) {
    final s = e.student;
    final photo = s?.photoUrl;
    final busy = _busyId == e.id;
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: e.isPending ? null : () => _openRecord(_who(e.studentId)),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.goldMuted,
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  child: photo == null
                      ? const Icon(
                          Icons.person,
                          color: AppColors.gold,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s?.displayName ?? '…',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_who(e.studentId).code != null)
                        Text(
                          _who(e.studentId).code!,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                            letterSpacing: 1.2,
                          ),
                        ),
                      const SizedBox(height: 3),
                      enrollmentStatusLine(e),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: t('tahfeez.chat'),
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.gold,
                    size: 20,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(enrollment: e),
                    ),
                  ),
                ),
                if (!e.isPending) ...[
                  _scoreChip(
                    _total(
                      e.studentId,
                      halaqaIds: _currentHalaqat(e.studentId),
                    ),
                  ),
                  Icon(tahfeezChevron, color: AppColors.textMuted),
                ],
              ],
            ),
          ),
          if (e.isPending && e.note != null && e.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.blackSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                e.note!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (e.isPending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _run(
                            e,
                            () => TahfeezService.decideEnrollment(
                              e.id,
                              approve: true,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: AppColors.textPrimary,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(t('tahfeez.approve')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _run(
                            e,
                            () => TahfeezService.decideEnrollment(
                              e.id,
                              approve: false,
                            ),
                          ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(t('tahfeez.reject')),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _run(
                          e,
                          () => TahfeezService.setEnrollmentPaid(e.id, !e.paid),
                        ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: e.paid
                        ? AppColors.textMuted
                        : AppColors.success,
                    side: BorderSide(
                      color: e.paid ? AppColors.goldBorder : AppColors.success,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    e.paid ? Icons.money_off : Icons.payments_outlined,
                    size: 15,
                  ),
                  label: Text(
                    e.paid ? t('tahfeez.markUnpaid') : t('tahfeez.markPaid'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () =>
                            _run(e, () => TahfeezService.renewEnrollment(e.id)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.goldBorder),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.autorenew, size: 15),
                  label: Text(
                    t('tahfeez.renew'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: busy ? null : () => _end(e),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.person_remove_outlined, size: 15),
                  label: Text(
                    t('tahfeez.endEnrollment'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _end(Enrollment e) async {
    final ok = await confirmDialog(
      context,
      message: t('tahfeez.endEnrollmentConfirm'),
      confirmLabel: t('tahfeez.endEnrollment'),
    );
    if (!ok || !mounted) return;
    await _run(e, () => TahfeezService.cancelEnrollment(e.id));
  }
}

/// "مشترك · ينتهي بعد 5 يوم · مدفوع · 2 حصص مجانية متبقية", in the colour
/// of its state. Shared by both sides of the enrolment.
Widget enrollmentStatusLine(Enrollment e) {
  final parts = <String>[];
  final Color color;
  if (e.isPending) {
    parts.add(t('tahfeez.status.pending'));
    color = AppColors.goldLight;
  } else if (e.status == EnrollmentStatus.rejected) {
    parts.add(t('tahfeez.status.rejected'));
    color = AppColors.textMuted;
  } else if (e.isExpired) {
    parts.add(t('tahfeez.status.expired'));
    parts.add('${t('tahfeez.endedSince')} ${-e.daysLeft} ${t('tahfeez.days')}');
    color = AppColors.error;
  } else {
    parts.add(t('tahfeez.status.active'));
    parts.add(
      e.daysLeft == 0
          ? t('tahfeez.endsToday')
          : '${t('tahfeez.endsIn')} ${e.daysLeft} ${t('tahfeez.days')}',
    );
    parts.add(e.paid ? t('tahfeez.paid') : t('tahfeez.unpaid'));
    if (e.freeSessionsLeft > 0) {
      parts.add('${e.freeSessionsLeft} ${t('tahfeez.freeLeft')}');
    }
    color = e.endsSoon ? AppColors.goldLight : AppColors.success;
  }
  return Text(
    parts.join(' · '),
    style: TextStyle(color: color, fontSize: 12, height: 1.5),
  );
}
