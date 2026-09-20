import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
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

  const ScheduleScreen({
    super.key,
    required this.halaqat,
    required this.sessions,
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
  bool _loadingStudents = true;
  String? _studentId;
  List<Evaluation> _studentEvals = const [];
  bool _loadingEvals = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime _firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  Future<void> _loadStudents() async {
    try {
      final lists = await Future.wait(
        widget.halaqat.map((h) => TahfeezService.members(h.id)),
      );
      final byId = <String, HalaqaMember>{};
      for (var i = 0; i < widget.halaqat.length; i++) {
        for (final m in lists[i]) {
          byId[m.studentId] = m;
          (_studentHalaqaIds[m.studentId] ??= {}).add(widget.halaqat[i].id);
        }
      }
      if (!mounted) return;
      setState(() {
        _students = byId.values.toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        _loadingStudents = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStudents = false);
    }
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
    return Directionality(
      textDirection: tahfeezDirection(),
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('tahfeez.calendar')),
        ),
        body: Column(
          children: [
            if (!_loadingStudents && _students.isNotEmpty) _studentFilterBar(),
            _monthHeader(),
            _weekdayHeader(),
            _monthGrid(),
            const Divider(color: AppColors.goldBorder, height: 1),
            Expanded(child: _dayDetail()),
          ],
        ),
        floatingActionButton: _selected == null ? null : _addButton(_selected!),
      ),
    );
  }

  Widget _studentFilterBar() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          _studentChip(null, t('tahfeez.allStudents')),
          for (final s in _students) _studentChip(s.studentId, s.name),
        ],
      ),
    );
  }

  Widget _studentChip(String? id, String label) {
    final active = _studentId == id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: GestureDetector(
        onTap: () => _pickStudent(id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.goldMuted : AppColors.blackSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: active ? AppColors.gold : AppColors.goldBorder,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: active ? AppColors.gold : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              if (active && _loadingEvals) ...[
                const SizedBox(width: 6),
                const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: AppColors.gold,
                  ),
                ),
              ],
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
          for (var d = 0; d < 7; d++)
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
    final lead = weekdayOf(_month);
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
      child: Container(
        margin: const EdgeInsets.all(2),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.gold : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isToday && !selected
              ? Border.all(color: AppColors.gold)
              : null,
        ),
        child: Column(
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: !inMonth
                    ? AppColors.textMuted.withValues(alpha: 0.4)
                    : selected
                    ? AppColors.black
                    : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: selected || isToday
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 5,
              width: 5,
              child: active
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: selected ? AppColors.black : AppColors.gold,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayDetail() {
    final selected = _selected;
    if (selected == null) {
      return EmptyNote(
        icon: Icons.event_available,
        text: t('tahfeez.pickDayHint'),
        hint: '',
      );
    }

    final weekday = weekdayOf(selected);
    final sessions = _sessionsOnWeekday(weekday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  formatDate(selected),
                  style: const TextStyle(
                    color: AppColors.textGold,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${sessions.length} / ${TahfeezService.maxSessionsPerDay}',
                style: TextStyle(
                  color: sessions.length >= TahfeezService.maxSessionsPerDay
                      ? AppColors.error
                      : AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: sessions.isEmpty
              ? EmptyNote(
                  icon: Icons.event_available,
                  text: t('tahfeez.noSessions'),
                  hint: t('tahfeez.noSessionsHint'),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                  itemCount: sessions.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _sessionCard(sessions[i], selected),
                ),
        ),
      ],
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
