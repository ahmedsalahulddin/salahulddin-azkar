import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
import 'availability_screen.dart' show availabilityWeekOrder, minutesLabel;
import 'session_evaluation_screen.dart';
import 'tahfeez_widgets.dart';

/// The teacher's schedule as a real monthly calendar: pick a year and month,
/// pick a day, see its sessions across every circle, add one (up to eight a
/// day) or take one away. A session stays a recurring weekly slot — there is
/// no per-date session of its own — so every occurrence of its weekday shows
/// up on the matching date in whichever month is on screen, and "adding a
/// session" on a tapped day still means adding to that weekday's slot,
/// exactly as it always has.
///
/// An optional student filter shades the calendar with that student's own
/// history: a past date lights up if they were actually evaluated that day,
/// a future date lights up if their circle has a recurring session on that
/// weekday — so a teacher can see at a glance how many days they worked with
/// someone already, and which are coming up.
class ScheduleScreen extends StatefulWidget {
  final List<Halaqa> halaqat;
  final List<TahfeezSession> sessions;

  /// The caller's own students — used only to tell a subscribed student
  /// from one who isn't, in the picker's filter.
  final List<Enrollment> enrollments;

  /// The teacher's available working hours, for the "free times" view: what
  /// is left of them once the sessions are taken out.
  final List<AvailabilitySlot> availability;

  /// Members to use instead of fetching — previews only.
  @visibleForTesting
  final List<HalaqaMember>? initialMembers;

  const ScheduleScreen({
    super.key,
    required this.halaqat,
    required this.sessions,
    this.enrollments = const [],
    this.availability = const [],
    this.initialMembers,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late List<TahfeezSession> _sessions = List.of(widget.sessions);
  late DateTime _month = _firstOfMonth(DateTime.now());
  DateTime? _selected = _dateOnly(DateTime.now());

  List<HalaqaMember> _students = const [];
  final Map<String, Set<String>> _studentHalaqaIds = {};
  Map<String, String> _studentEmails = const {};
  bool _loadingStudents = true;
  String? _studentId;
  List<Evaluation> _studentEvals = const [];
  bool _loadingEvals = false;

  /// Working times (the sessions) or free times (available hours left over).
  bool _freeMode = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialMembers != null) {
      for (final m in widget.initialMembers!) {
        (_studentHalaqaIds[m.studentId] ??= {}).add(m.halaqaId);
      }
      _students = {
        for (final m in widget.initialMembers!) m.studentId: m,
      }.values.toList();
      _loadingStudents = false;
    } else {
      _loadStudents();
    }
  }

  /// What is left of [weekday]'s available hours once its sessions are taken
  /// out, as (from, to) minutes.
  List<(int, int)> _freeRanges(int weekday) {
    var free = [
      for (final a in widget.availability)
        if (a.weekday == weekday) (a.from, a.to),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    for (final s in _sessionsOnWeekday(weekday)) {
      final bs = _minutes(s.start);
      final be = _minutes(s.end);
      free = [
        for (final (f, t) in free) ...[
          if (be <= f || bs >= t) (f, t),
          if (!(be <= f || bs >= t) && bs > f) (f, bs),
          if (!(be <= f || bs >= t) && be < t) (be, t),
        ],
      ];
    }
    return free.where((r) => r.$2 - r.$1 >= 15).toList();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  Future<void> _loadStudents() async {
    try {
      final results = await Future.wait([
        Future.wait(widget.halaqat.map((h) => TahfeezService.members(h.id))),
        Future.wait(
          widget.halaqat.map((h) => TahfeezService.memberEmails(h.id)),
        ),
      ]);
      final memberLists = results[0] as List<List<HalaqaMember>>;
      final emailMaps = results[1] as List<Map<String, String>>;

      final byId = <String, HalaqaMember>{};
      final emails = <String, String>{};
      for (var i = 0; i < widget.halaqat.length; i++) {
        for (final m in memberLists[i]) {
          byId[m.studentId] = m;
          (_studentHalaqaIds[m.studentId] ??= {}).add(widget.halaqat[i].id);
        }
        emails.addAll(emailMaps[i]);
      }
      if (!mounted) return;
      setState(() {
        _students = byId.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _studentEmails = emails;
        _loadingStudents = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStudents = false);
    }
  }

  /// A student counts as subscribed while they have an accepted, unexpired
  /// term with the caller — the same "اشتراك" the teacher directory tracks.
  bool _isSubscribed(String studentId) {
    for (final e in widget.enrollments) {
      if (e.studentId == studentId &&
          e.status == EnrollmentStatus.active &&
          e.daysLeft >= 0) {
        return true;
      }
    }
    return false;
  }

  String? _nameOf(String? id) {
    if (id == null) return null;
    for (final s in _students) {
      if (s.studentId == id) return s.name;
    }
    return null;
  }

  /// The sheet pops '' for an explicit "كل الطلاب" choice and a student id
  /// for a student — never null, which is reserved for "dismissed without
  /// choosing", so swiping the sheet away never silently clears an active
  /// filter.
  Future<void> _openStudentPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _StudentPickerSheet(
        students: _students,
        emails: _studentEmails,
        isSubscribed: _isSubscribed,
        selectedId: _studentId,
      ),
    );
    if (picked == null) return;
    _pickStudent(picked.isEmpty ? null : picked);
  }

  Future<void> _pickStudent(String? id) async {
    setState(() {
      _studentId = id;
      _studentEvals = const [];
    });
    if (id == null) return;
    setState(() => _loadingEvals = true);
    try {
      final all = await TahfeezService.evaluationsOf(id);
      final mySessionIds = _sessions.map((s) => s.id).toSet();
      final mine = all
          .where((e) => mySessionIds.contains(e.sessionId))
          .toList();
      if (mounted) {
        setState(() {
          _studentEvals = mine;
          _loadingEvals = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingEvals = false);
    }
  }

  List<TahfeezSession> _sessionsOnWeekday(int weekday) {
    final ids = widget.halaqat.map((h) => h.id).toSet();
    return _sessions
        .where((s) => s.weekday == weekday && ids.contains(s.halaqaId))
        .toList()
      ..sort((a, b) => _minutes(a.start).compareTo(_minutes(b.start)));
  }

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Halaqa? _halaqaOf(String id) {
    for (final h in widget.halaqat) {
      if (h.id == id) return h;
    }
    return null;
  }

  /// Whether [date] should light up in the calendar — every weekday that
  /// carries a session when no student is picked, or that student's own
  /// evaluated/scheduled days once one is.
  bool _isActive(DateTime date) {
    final weekday = weekdayOf(date);
    if (_freeMode) return _freeRanges(weekday).isNotEmpty;
    if (_studentId == null) return _sessionsOnWeekday(weekday).isNotEmpty;

    final today = _dateOnly(DateTime.now());
    if (!date.isAfter(today)) {
      return _studentEvals.any((e) => isSameDate(e.date, date));
    }
    final halaqaIds = _studentHalaqaIds[_studentId] ?? const {};
    return _sessionsOnWeekday(
      weekday,
    ).any((s) => halaqaIds.contains(s.halaqaId));
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta, 1);
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.halaqat.isEmpty) {
      return Directionality(
        textDirection: tahfeezDirection(),
        child: Scaffold(
          backgroundColor: AppColors.black,
          appBar: AppBar(
            backgroundColor: AppColors.black,
            foregroundColor: AppColors.gold,
            title: Text(t('tahfeez.calendar')),
          ),
          body: EmptyNote(
            icon: Icons.groups_outlined,
            text: t('tahfeez.needHalaqaFirst'),
            hint: t('tahfeez.needHalaqaFirstHint'),
          ),
        ),
      );
    }

    return Directionality(
      textDirection: tahfeezDirection(),
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('tahfeez.calendar')),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 90),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  Expanded(child: _modeSwitch()),
                  if (!_loadingStudents && _students.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Expanded(child: _studentFilterButton()),
                  ],
                ],
              ),
            ),
            _monthHeader(),
            _weekdayHeader(),
            _monthGrid(),
            const Divider(color: AppColors.goldBorder, height: 1),
            const SizedBox(height: 8),
            ..._weekList(),
          ],
        ),
        floatingActionButton: _selected == null || _freeMode
            ? null
            : _addButton(_selected!),
      ),
    );
  }

  /// One tappable row instead of a chip per student — with 200+ students a
  /// horizontal scroll of chips has no way to find one by name. Opens a
  /// searchable picker instead.
  Widget _studentFilterButton() {
    final label = _nameOf(_studentId) ?? t('tahfeez.allStudents');
    return Padding(
      padding: EdgeInsets.zero,
      child: GestureDetector(
        onTap: _openStudentPicker,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: _studentId == null
                ? AppColors.blackSurface
                : AppColors.goldMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _studentId == null ? AppColors.goldBorder : AppColors.gold,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.filter_list,
                size: 16,
                color: _studentId == null
                    ? AppColors.textMuted
                    : AppColors.gold,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _studentId == null
                        ? AppColors.textSecondary
                        : AppColors.gold,
                    fontSize: 13,
                    fontWeight: _studentId == null
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
              ),
              if (_loadingEvals)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.gold,
                  ),
                )
              else
                Icon(
                  Icons.expand_more,
                  size: 18,
                  color: _studentId == null
                      ? AppColors.textMuted
                      : AppColors.gold,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _monthHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right, color: AppColors.gold),
            onPressed: () => _changeMonth(1),
          ),
          Expanded(
            child: Text(
              '${monthName(_month.month)} ${_month.year}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textGold,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left, color: AppColors.gold),
            onPressed: () => _changeMonth(-1),
          ),
        ],
      ),
    );
  }

  Widget _weekdayHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final d in availabilityWeekOrder)
            Expanded(
              child: Center(
                child: Text(
                  _shortDay(d),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _shortDay(int d) {
    final full = weekdayName(d);
    final chars = full.startsWith('ال') && full.length > 4
        ? full.substring(2).characters
        : full.characters;
    return chars.take(2).toString();
  }

  Widget _monthGrid() {
    // Columns run Saturday … Friday.
    final lead = availabilityWeekOrder.indexOf(weekdayOf(_month));
    final gridStart = _month.subtract(Duration(days: lead));
    final today = _dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          for (var row = 0; row < 6; row++)
            Row(
              children: [
                for (var col = 0; col < 7; col++)
                  Expanded(
                    child: _dayCell(
                      gridStart.add(Duration(days: row * 7 + col)),
                      today,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _dayCell(DateTime date, DateTime today) {
    final inMonth = date.month == _month.month;
    final selected = _selected != null && isSameDate(date, _selected!);
    final isToday = isSameDate(date, today);
    final active = inMonth && _isActive(date);

    return GestureDetector(
      onTap: () => setState(() => _selected = date),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 42,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? AppColors.gold
                  : active
                  ? AppColors.gold.withValues(alpha: 0.28)
                  : Colors.transparent,
              border: selected
                  ? null
                  : active
                  ? Border.all(color: AppColors.gold)
                  : isToday
                  ? Border.all(color: AppColors.gold.withValues(alpha: 0.6))
                  : null,
            ),
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: !inMonth
                    ? AppColors.textMuted.withValues(alpha: 0.4)
                    : selected
                    ? AppColors.black
                    : active
                    ? AppColors.gold
                    : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: selected || active || isToday
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Working times / free times as one switch.
  Widget _modeSwitch() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.blackSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          for (final (free, label) in [
            (false, t('tahfeez.mode.work')),
            (true, t('tahfeez.mode.free')),
          ])
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _freeMode = free),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: free == _freeMode
                        ? AppColors.gold
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: free == _freeMode
                          ? AppColors.black
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: free == _freeMode
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

  /// The week under the calendar, Saturday first: each day with its session
  /// times (for the picked student, if any) or its free times. The selected
  /// date's day is outlined, and in working times its sessions open below.
  List<Widget> _weekList() {
    final selectedDay = _selected == null ? null : weekdayOf(_selected!);
    if (_freeMode && widget.availability.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(16),
          child: EmptyNote(
            icon: Icons.event_available,
            text: t('tahfeez.freeNeedsAvail'),
          ),
        ),
      ];
    }
    final studentHalaqat = _studentId == null
        ? null
        : (_studentHalaqaIds[_studentId] ?? const <String>{});
    return [
      for (final d in availabilityWeekOrder) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: _dayRow(d, d == selectedDay, studentHalaqat),
        ),
      ],
    ];
  }

  Widget _dayRow(int weekday, bool selected, Set<String>? studentHalaqat) {
    final sessions = _sessionsOnWeekday(weekday)
        .where(
          (s) => studentHalaqat == null || studentHalaqat.contains(s.halaqaId),
        )
        .toList();
    final free = _freeMode ? _freeRanges(weekday) : const <(int, int)>[];
    final chips = _freeMode
        ? [
            for (final (f, to) in free)
              '${minutesLabel(f)} – ${minutesLabel(to)}',
          ]
        : [
            for (final s in sessions)
              '${formatTime(s.start)} – ${formatTime(s.end)}'
                  '${_halaqaOf(s.halaqaId) == null ? '' : ' · ${_halaqaOf(s.halaqaId)!.name}'}',
          ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.gold : AppColors.goldBorder,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  weekdayName(weekday),
                  style: TextStyle(
                    color: chips.isEmpty ? AppColors.textMuted : AppColors.gold,
                    fontSize: 13,
                    fontWeight: chips.isEmpty
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: chips.isEmpty
                    ? Text(
                        _freeMode ? t('tahfeez.freeNone') : '—',
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 12,
                        ),
                      )
                    : Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final c in chips)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: _freeMode
                                    ? AppColors.success.withValues(alpha: 0.12)
                                    : AppColors.goldMuted,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                c,
                                style: TextStyle(
                                  color: _freeMode
                                      ? AppColors.success
                                      : AppColors.gold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),
          if (selected && !_freeMode && sessions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              formatDate(_selected!),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 6),
            for (final s in sessions) ...[
              _sessionCard(s, _selected!),
              const SizedBox(height: 6),
            ],
          ],
        ],
      ),
    );
  }

  Widget _sessionCard(TahfeezSession s, DateTime date) {
    final h = _halaqaOf(s.halaqaId);
    return TahfeezCard(
      onTap: h == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    SessionEvaluationScreen(session: s, halaqa: h, date: date),
              ),
            ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.goldMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${formatTime(s.start)}\n${formatTime(s.end)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              h?.name ?? '',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              color: AppColors.textMuted,
              size: 20,
            ),
            onPressed: () => _delete(s),
          ),
        ],
      ),
    );
  }

  Future<void> _delete(TahfeezSession s) async {
    final ok = await confirmDialog(
      context,
      message: t('tahfeez.deleteSessionConfirm'),
    );
    if (!ok || !mounted) return;
    try {
      await TahfeezService.deleteSession(s.id);
      setState(() => _sessions = _sessions.where((x) => x.id != s.id).toList());
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Widget _addButton(DateTime date) {
    final weekday = weekdayOf(date);
    final today = _sessionsOnWeekday(weekday);
    final full = today.length >= TahfeezService.maxSessionsPerDay;
    return FloatingActionButton.extended(
      onPressed: full || widget.halaqat.isEmpty ? null : () => _add(weekday),
      backgroundColor: full || widget.halaqat.isEmpty
          ? AppColors.blackSurface
          : AppColors.gold,
      foregroundColor: full || widget.halaqat.isEmpty
          ? AppColors.textMuted
          : AppColors.black,
      icon: const Icon(Icons.add),
      label: Text(full ? t('tahfeez.sessionLimit') : t('tahfeez.addSession')),
    );
  }

  Future<void> _add(int weekday) async {
    final result = await showModalBottomSheet<TahfeezSession>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) =>
          _AddSessionSheet(halaqat: widget.halaqat, weekday: weekday),
    );
    if (result != null && mounted) {
      setState(() => _sessions = [..._sessions, result]);
    }
  }
}

class _AddSessionSheet extends StatefulWidget {
  final List<Halaqa> halaqat;
  final int weekday;

  const _AddSessionSheet({required this.halaqat, required this.weekday});

  @override
  State<_AddSessionSheet> createState() => _AddSessionSheetState();
}

class _AddSessionSheetState extends State<_AddSessionSheet> {
  late String _halaqaId = widget.halaqat.first.id;
  TimeOfDay _start = const TimeOfDay(hour: 16, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: tahfeezDirection(),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${t('tahfeez.addSession')} — ${weekdayName(widget.weekday)}',
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('tahfeez.halaqa'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            DropdownButtonFormField<String>(
              initialValue: _halaqaId,
              dropdownColor: AppColors.blackSurface,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: _fieldDecoration(),
              items: [
                for (final h in widget.halaqat)
                  DropdownMenuItem(value: h.id, child: Text(h.name)),
              ],
              onChanged: (v) => setState(() => _halaqaId = v ?? _halaqaId),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _timeField(t('tahfeez.from'), _start, true)),
                const SizedBox(width: 10),
                Expanded(child: _timeField(t('tahfeez.to'), _end, false)),
              ],
            ),
            const SizedBox(height: 20),
            GoldButton(
              label: t('tahfeez.save'),
              icon: Icons.check,
              busy: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration() => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: AppColors.blackSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.goldBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.goldBorder),
    ),
  );

  Widget _timeField(String label, TimeOfDay value, bool isStart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: value,
              builder: (ctx, child) => Theme(
                data: Theme.of(ctx).copyWith(
                  colorScheme: const ColorScheme.dark(
                    primary: AppColors.gold,
                    surface: AppColors.blackCard,
                  ),
                ),
                child: child!,
              ),
            );
            if (picked == null) return;
            setState(() {
              if (isStart) {
                _start = picked;
                if (_minutes(_end) <= _minutes(_start)) {
                  _end = TimeOfDay(
                    hour: (picked.hour + 1) % 24,
                    minute: picked.minute,
                  );
                }
              } else {
                _end = picked;
              }
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.blackSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.goldBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppColors.gold),
                const SizedBox(width: 8),
                Text(
                  formatTime(value),
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static int _minutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _save() async {
    if (_minutes(_end) <= _minutes(_start)) {
      showNote(context, t('tahfeez.endBeforeStart'), error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final s = await TahfeezService.addSession(
        halaqaId: _halaqaId,
        weekday: widget.weekday,
        start: _start,
        end: _end,
      );
      if (mounted) Navigator.pop(context, s);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showNote(context, describeError(e), error: true);
      }
    }
  }
}

enum _SubFilter { all, subscribed, unsubscribed }

/// Searchable by name or student code, with a subscribed/not-subscribed toggle —
/// the flat chip row it replaces had no way to find one student among two
/// hundred.
class _StudentPickerSheet extends StatefulWidget {
  final List<HalaqaMember> students;
  final Map<String, String> emails;
  final bool Function(String studentId) isSubscribed;
  final String? selectedId;

  const _StudentPickerSheet({
    required this.students,
    required this.emails,
    required this.isSubscribed,
    required this.selectedId,
  });

  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  _SubFilter _filter = _SubFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<HalaqaMember> get _filtered {
    final q = _query.trim().toLowerCase();
    return widget.students.where((s) {
      if (_filter == _SubFilter.subscribed &&
          !widget.isSubscribed(s.studentId)) {
        return false;
      }
      if (_filter == _SubFilter.unsubscribed &&
          widget.isSubscribed(s.studentId)) {
        return false;
      }
      if (q.isEmpty) return true;
      final email = widget.emails[s.studentId] ?? '';
      return s.name.toLowerCase().contains(q) ||
          email.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Directionality(
      textDirection: tahfeezDirection(),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => SafeArea(
          top: false,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: t('tahfeez.searchStudent'),
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    filled: true,
                    fillColor: AppColors.blackSurface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.goldBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _filterChip(_SubFilter.all, t('tahfeez.allStudents')),
                    const SizedBox(width: 6),
                    _filterChip(_SubFilter.subscribed, t('tahfeez.subscribed')),
                    const SizedBox(width: 6),
                    _filterChip(
                      _SubFilter.unsubscribed,
                      t('tahfeez.notSubscribed'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(color: AppColors.goldBorder, height: 1),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text(
                          t('tahfeez.noStudentsFound'),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: list.length + 1,
                        itemBuilder: (ctx, i) {
                          if (i == 0) {
                            final allSelected = widget.selectedId == null;
                            return ListTile(
                              leading: Icon(
                                Icons.groups,
                                color: allSelected
                                    ? AppColors.gold
                                    : AppColors.textMuted,
                              ),
                              title: Text(
                                t('tahfeez.allStudents'),
                                style: TextStyle(
                                  color: allSelected
                                      ? AppColors.gold
                                      : AppColors.textPrimary,
                                  fontWeight: allSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              onTap: () => Navigator.pop(context, ''),
                            );
                          }
                          final s = list[i - 1];
                          final email = widget.emails[s.studentId];
                          final selected = s.studentId == widget.selectedId;
                          final subscribed = widget.isSubscribed(s.studentId);
                          return ListTile(
                            leading: Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.person_outline,
                              size: 20,
                              color: selected
                                  ? AppColors.gold
                                  : AppColors.textMuted,
                            ),
                            title: Text(
                              s.name,
                              style: TextStyle(
                                color: selected
                                    ? AppColors.gold
                                    : AppColors.textPrimary,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: email == null
                                ? null
                                : Text(
                                    email,
                                    textDirection: TextDirection.ltr,
                                    style: const TextStyle(
                                      color: AppColors.textMuted,
                                      fontSize: 11,
                                    ),
                                  ),
                            trailing: subscribed
                                ? const Icon(
                                    Icons.verified,
                                    size: 16,
                                    color: AppColors.emeraldLight,
                                  )
                                : null,
                            onTap: () => Navigator.pop(context, s.studentId),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(_SubFilter f, String label) {
    final active = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.goldMuted : AppColors.blackSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? AppColors.gold : AppColors.goldBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.gold : AppColors.textMuted,
            fontSize: 12,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
