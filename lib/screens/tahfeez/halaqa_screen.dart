import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
import 'availability_screen.dart' show availabilityWeekOrder;
import 'session_evaluation_screen.dart';
import 'student_record_screen.dart';
import 'tahfeez_widgets.dart';

/// A teacher's view of one circle, in three parts switched at the top: its
/// students ranked by their points here (alphabetically while nobody has
/// any), its sessions in week order with how long each runs, and a month
/// calendar to pick the session days, with the working hours of each day
/// underneath.
class HalaqaScreen extends StatefulWidget {
  final Halaqa halaqa;

  /// Data to show instead of fetching — previews only.
  @visibleForTesting
  final List<HalaqaMember>? initialMembers;
  @visibleForTesting
  final List<TahfeezSession>? initialSessions;
  @visibleForTesting
  final List<Evaluation>? initialEvaluations;

  const HalaqaScreen({
    super.key,
    required this.halaqa,
    this.initialMembers,
    this.initialSessions,
    this.initialEvaluations,
  });

  @override
  State<HalaqaScreen> createState() => _HalaqaScreenState();
}

enum _Part { students, sessions, calendar }

class _HalaqaScreenState extends State<HalaqaScreen> {
  late Halaqa _halaqa = widget.halaqa;
  List<HalaqaMember> _members = const [];
  List<TahfeezSession> _sessions = const [];
  List<Evaluation> _evaluations = const [];
  bool _loading = true;
  _Part _part = _Part.students;
  String _query = '';
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  bool get _offline => widget.initialMembers != null;

  @override
  void initState() {
    super.initState();
    if (_offline) {
      _members = widget.initialMembers!;
      _sessions = widget.initialSessions ?? const [];
      _evaluations = widget.initialEvaluations ?? const [];
      _loading = false;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        TahfeezService.members(_halaqa.id),
        TahfeezService.visibleSessions(),
      ]);
      final sessions = (results[1] as List<TahfeezSession>)
          .where((s) => s.halaqaId == _halaqa.id)
          .toList();
      final evaluations = await TahfeezService.evaluationsInSessions([
        for (final s in sessions) s.id,
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<HalaqaMember>;
        _sessions = sessions;
        _evaluations = evaluations;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNote(context, describeError(e), error: true);
    }
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
          title: Text(_halaqa.name),
          actions: [
            PopupMenuButton<String>(
              color: AppColors.blackCard,
              onSelected: (v) => v == 'rename' ? _rename() : _delete(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'rename',
                  child: Text(
                    t('tahfeez.rename'),
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(
                    t('tahfeez.delete'),
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: _switch(),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.gold,
                      backgroundColor: AppColors.blackCard,
                      onRefresh: _offline ? () async {} : _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 30),
                        children: switch (_part) {
                          _Part.students => _studentsPart(),
                          _Part.sessions => _sessionsPart(),
                          _Part.calendar => _calendarPart(),
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _switch() {
    final items = [
      (
        _Part.students,
        Icons.groups,
        '${t('tahfeez.students')} (${_members.length})',
      ),
      (_Part.sessions, Icons.schedule, t('tahfeez.part.sessions')),
      (_Part.calendar, Icons.calendar_month, t('tahfeez.part.calendar')),
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
          for (final (part, icon, label) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _part = part),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: part == _part ? AppColors.gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        icon,
                        size: 18,
                        color: part == _part ? AppColors.black : AppColors.gold,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: part == _part
                              ? AppColors.black
                              : AppColors.textSecondary,
                          fontSize: 11.5,
                          fontWeight: part == _part
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---- students ------------------------------------------------------------

  int _pointsOf(String studentId) => _evaluations
      .where((e) => e.studentId == studentId)
      .fold(0, (a, e) => a + e.score);

  List<Widget> _studentsPart() {
    final q = _query.trim().toLowerCase();
    final shown = _members.where((m) {
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) ||
          (m.profile?.studentCode?.toLowerCase().contains(q) ?? false);
    }).toList();
    final anyPoints = _evaluations.isNotEmpty;
    shown.sort((a, b) {
      if (anyPoints) {
        final byPoints = _pointsOf(
          b.studentId,
        ).compareTo(_pointsOf(a.studentId));
        if (byPoints != 0) return byPoints;
      }
      return a.name.compareTo(b.name);
    });
    return [
      TextField(
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
      ),
      const SizedBox(height: 10),
      _codeCard(),
      const SizedBox(height: 12),
      if (_members.isEmpty)
        EmptyNote(icon: Icons.groups_outlined, text: t('tahfeez.noStudents'))
      else
        for (final (i, m) in shown.indexed) ...[
          _memberCard(m, rank: anyPoints ? i + 1 : null),
          const SizedBox(height: 8),
        ],
    ];
  }

  // ---- sessions ------------------------------------------------------------

  /// Sessions in week order (Saturday first), then by start time.
  List<TahfeezSession> get _ordered => [
    for (final d in availabilityWeekOrder)
      ...(_sessions.where((s) => s.weekday == d).toList()..sort(
        (a, b) => (a.start.hour * 60 + a.start.minute).compareTo(
          b.start.hour * 60 + b.start.minute,
        ),
      )),
  ];

  List<Widget> _sessionsPart() => [
    if (_sessions.isEmpty)
      EmptyNote(icon: Icons.event_busy, text: t('tahfeez.noSessionsInHalaqa'))
    else
      for (final s in _ordered) ...[_sessionCard(s), const SizedBox(height: 8)],
  ];

  // ---- calendar ------------------------------------------------------------

  Set<int> get _sessionDays => {for (final s in _sessions) s.weekday};

  List<Widget> _calendarPart() {
    final first = _month;
    final daysInMonth = DateTime(first.year, first.month + 1, 0).day;
    // Columns run Saturday … Friday; find where the 1st falls.
    final lead = availabilityWeekOrder.indexOf(weekdayOf(first));
    final today = DateTime.now();
    final cells = <DateTime?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= daysInMonth; d++)
        DateTime(first.year, first.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return [
      TahfeezCard(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month - 1),
                  ),
                  icon: Icon(
                    tahfeezDirection() == TextDirection.rtl
                        ? Icons.chevron_right
                        : Icons.chevron_left,
                    color: AppColors.gold,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${monthName(_month.month)} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(
                    () => _month = DateTime(_month.year, _month.month + 1),
                  ),
                  icon: Icon(
                    tahfeezDirection() == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    color: AppColors.gold,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                for (final d in availabilityWeekOrder)
                  Expanded(
                    child: Text(
                      weekdayName(d),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: _sessionDays.contains(d)
                            ? AppColors.gold
                            : AppColors.textMuted,
                        fontSize: 10.5,
                        fontWeight: _sessionDays.contains(d)
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var r = 0; r < cells.length; r += 7)
              Row(
                children: [
                  for (final c in cells.sublist(r, r + 7))
                    Expanded(child: _dayCell(c, today)),
                ],
              ),
          ],
        ),
      ),
      const SizedBox(height: 6),
      Text(
        t('tahfeez.calendarHint'),
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 14),
      SectionTitle(t('tahfeez.workingHours')),
      for (final d in availabilityWeekOrder) ...[
        _workingDay(d),
        const SizedBox(height: 6),
      ],
    ];
  }

  Widget _dayCell(DateTime? day, DateTime today) {
    if (day == null) return const SizedBox(height: 40);
    final on = _sessionDays.contains(weekdayOf(day));
    final isToday =
        day.year == today.year &&
        day.month == today.month &&
        day.day == today.day;
    return GestureDetector(
      onTap: () => _dayTapped(weekdayOf(day)),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 40,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(
                  color: on ? AppColors.black : AppColors.gold,
                  width: 1.5,
                )
              : null,
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
            color: on ? AppColors.black : AppColors.textSecondary,
            fontSize: 14,
            fontWeight: on ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  /// A day with sessions lists them to change or add to; a free day asks
  /// for the hours of a new session on it.
  Future<void> _dayTapped(int weekday) async {
    if (!_sessionDays.contains(weekday)) {
      await _addOn(weekday);
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: tahfeezDirection(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: StatefulBuilder(
              builder: (ctx, refresh) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    weekdayName(weekday),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _workingDay(weekday, onChanged: () => refresh(() {})),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// One day of the week with its session times as chips: tap a time to
  /// change it, × to remove it, + to add another.
  Widget _workingDay(int weekday, {VoidCallback? onChanged}) {
    final list = _ordered.where((s) => s.weekday == weekday).toList();
    return TahfeezCard(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              weekdayName(weekday),
              style: TextStyle(
                color: list.isEmpty ? AppColors.textMuted : AppColors.gold,
                fontSize: 13,
                fontWeight: list.isEmpty ? FontWeight.normal : FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final s in list)
                  InputChip(
                    label: Text(
                      '${formatTime(s.start)} – ${formatTime(s.end)}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: AppColors.goldMuted,
                    side: const BorderSide(color: AppColors.goldBorder),
                    deleteIconColor: AppColors.textMuted,
                    onPressed: () async {
                      await _editTime(s);
                      onChanged?.call();
                    },
                    onDeleted: () async {
                      await _deleteSession(s);
                      onChanged?.call();
                    },
                  ),
                ActionChip(
                  avatar: const Icon(
                    Icons.add,
                    size: 16,
                    color: AppColors.gold,
                  ),
                  label: Text(
                    list.isEmpty
                        ? t('tahfeez.addWorkTime')
                        : t('tahfeez.avail.addRange'),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  backgroundColor: AppColors.blackSurface,
                  side: const BorderSide(color: AppColors.goldBorder),
                  onPressed: () async {
                    await _addOn(weekday);
                    onChanged?.call();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Asks for a start and an end; null if cancelled or the end isn't later.
  Future<(TimeOfDay, TimeOfDay)?> _askTimes({
    TimeOfDay start = const TimeOfDay(hour: 15, minute: 0),
    TimeOfDay end = const TimeOfDay(hour: 17, minute: 0),
  }) async {
    final from = await showTimePicker(
      context: context,
      initialTime: start,
      helpText: t('tahfeez.avail.from'),
    );
    if (from == null || !mounted) return null;
    final to = await showTimePicker(
      context: context,
      initialTime: end,
      helpText: t('tahfeez.avail.to'),
    );
    if (to == null || !mounted) return null;
    if (to.hour * 60 + to.minute <= from.hour * 60 + from.minute) {
      showNote(context, t('tahfeez.avail.badRange'), error: true);
      return null;
    }
    return (from, to);
  }

  Future<void> _addOn(int weekday) async {
    final times = await _askTimes();
    if (times == null) return;
    final (start, end) = times;
    try {
      final created = _offline
          ? TahfeezSession(
              id: 'local-${DateTime.now().microsecondsSinceEpoch}',
              halaqaId: _halaqa.id,
              weekday: weekday,
              start: start,
              end: end,
            )
          : await TahfeezService.addSession(
              halaqaId: _halaqa.id,
              weekday: weekday,
              start: start,
              end: end,
            );
      if (mounted) setState(() => _sessions = [..._sessions, created]);
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _editTime(TahfeezSession s) async {
    final times = await _askTimes(start: s.start, end: s.end);
    if (times == null) return;
    final (start, end) = times;
    try {
      if (!_offline) await TahfeezService.updateSessionTime(s.id, start, end);
      if (!mounted) return;
      setState(() {
        _sessions = [
          for (final x in _sessions)
            if (x.id == s.id)
              TahfeezSession(
                id: x.id,
                halaqaId: x.halaqaId,
                weekday: x.weekday,
                start: start,
                end: end,
              )
            else
              x,
        ];
      });
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _deleteSession(TahfeezSession s) async {
    final ok = await confirmDialog(
      context,
      message: t('tahfeez.deleteSessionConfirm'),
    );
    if (!ok || !mounted) return;
    try {
      if (!_offline) await TahfeezService.deleteSession(s.id);
      if (mounted) {
        setState(
          () => _sessions = _sessions.where((x) => x.id != s.id).toList(),
        );
      }
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Widget _codeCard() {
    return TahfeezCard(
      onTap: _addStudent,
      child: Row(
        children: [
          const Icon(Icons.person_add_alt_1, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('tahfeez.addStudent'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  t('tahfeez.addStudentSub'),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Icon(tahfeezChevron, color: AppColors.textMuted),
        ],
      ),
    );
  }

  /// Picks from the teacher's active subscribers who are not in yet.
  Future<void> _addStudent() async {
    final List<Enrollment> enrollments;
    try {
      enrollments = await TahfeezService.enrollments();
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
      return;
    }
    if (!mounted) return;
    final inHalaqa = _members.map((m) => m.studentId).toSet();
    final candidates = enrollments
        .where((e) => e.isActive && e.student != null)
        .where((e) => !inHalaqa.contains(e.studentId))
        .toList();
    if (candidates.isEmpty) {
      showNote(context, t('tahfeez.noStudentsToAdd'));
      return;
    }
    final picked = await showModalBottomSheet<Enrollment>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Directionality(
        textDirection: tahfeezDirection(),
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            children: [
              Text(
                t('tahfeez.addStudent'),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              for (final e in candidates)
                ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.goldMuted,
                    backgroundImage: e.student!.photoUrl != null
                        ? NetworkImage(e.student!.photoUrl!)
                        : null,
                    child: e.student!.photoUrl == null
                        ? const Icon(Icons.person, color: AppColors.gold)
                        : null,
                  ),
                  title: Text(
                    e.student!.displayName,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  onTap: () => Navigator.pop(ctx, e),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    try {
      await TahfeezService.assignToHalaqa(_halaqa.id, picked.studentId);
      await _load();
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Widget _memberCard(HalaqaMember m, {int? rank}) {
    final photo = m.profile?.photoUrl;
    final mine = _evaluations.where((e) => e.studentId == m.studentId).toList();
    return TahfeezCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => HalaqaRecordScreen(
            student: TeacherStudent(
              id: m.studentId,
              name: m.name,
              code: m.profile?.studentCode,
              photoUrl: photo,
            ),
            halaqa: _halaqa,
            sessions: _sessions,
            evaluations: mine,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          if (rank != null) ...[
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: rank <= 3 ? AppColors.gold : AppColors.textMuted,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.goldMuted,
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? const Icon(Icons.person, color: AppColors.gold, size: 20)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                if (m.profile?.studentCode != null)
                  Text(
                    m.profile!.studentCode!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.textGold,
                      fontSize: 11,
                      letterSpacing: 1.2,
                    ),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.goldMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_pointsOf(m.studentId)} ${t('tahfeez.points')}',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: t('tahfeez.removeStudent'),
            icon: const Icon(
              Icons.person_remove_outlined,
              color: AppColors.textMuted,
              size: 20,
            ),
            onPressed: () => _removeMember(m),
          ),
        ],
      ),
    );
  }

  Widget _sessionCard(TahfeezSession s) {
    return TahfeezCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SessionEvaluationScreen(
            session: s,
            halaqa: _halaqa,
            date: DateTime.now(),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.schedule, color: AppColors.gold, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  weekdayName(s.weekday),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${formatTime(s.start)} – ${formatTime(s.end)} · '
                  '${durationLabel(sessionMinutes(s))}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            t('tahfeez.evaluate'),
            style: const TextStyle(color: AppColors.gold, fontSize: 12),
          ),
          Icon(tahfeezChevron, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Future<void> _removeMember(HalaqaMember m) async {
    final ok = await confirmDialog(
      context,
      message: t('tahfeez.removeStudentConfirm'),
      confirmLabel: t('tahfeez.removeStudent'),
    );
    if (!ok || !mounted) return;
    try {
      await TahfeezService.removeMember(_halaqa.id, m.studentId);
      setState(() => _members = _members.where((x) => x != m).toList());
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _rename() async {
    final name = await promptText(
      context,
      title: t('tahfeez.rename'),
      hint: t('tahfeez.halaqaNameHint'),
      initial: _halaqa.name,
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await TahfeezService.renameHalaqa(_halaqa.id, name);
      setState(() {
        _halaqa = Halaqa(
          id: _halaqa.id,
          teacherId: _halaqa.teacherId,
          name: name,
          inviteCode: _halaqa.inviteCode,
        );
      });
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(
      context,
      message: t('tahfeez.deleteHalaqaConfirm'),
    );
    if (!ok || !mounted) return;
    try {
      await TahfeezService.deleteHalaqa(_halaqa.id);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }
}
