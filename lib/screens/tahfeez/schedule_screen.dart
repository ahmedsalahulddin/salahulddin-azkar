import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
import 'session_evaluation_screen.dart';
import 'tahfeez_widgets.dart';

/// The teacher's week: pick a day, see its sessions across every circle,
/// add one (up to eight a day) or take one away.
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
  late int _day = weekdayOf(DateTime.now());

  List<TahfeezSession> _ofDay(int day) {
    final ids = widget.halaqat.map((h) => h.id).toSet();
    return _sessions
        .where((s) => s.weekday == day && ids.contains(s.halaqaId))
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

  @override
  Widget build(BuildContext context) {
    final today = _ofDay(_day);
    final full = today.length >= TahfeezService.maxSessionsPerDay;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('tahfeez.schedule')),
        ),
        body: Column(
          children: [
            _dayStrip(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      weekdayName(_day),
                      style: const TextStyle(
                        color: AppColors.textGold,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Text(
                    '${today.length} / ${TahfeezService.maxSessionsPerDay}',
                    style: TextStyle(
                      color: full ? AppColors.error : AppColors.textMuted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: today.isEmpty
                  ? EmptyNote(
                      icon: Icons.event_available,
                      text: t('tahfeez.noSessions'),
                      hint: t('tahfeez.noSessionsHint'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: today.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _sessionCard(today[i]),
                    ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: full || widget.halaqat.isEmpty ? null : _add,
          backgroundColor: full || widget.halaqat.isEmpty
              ? AppColors.blackSurface
              : AppColors.gold,
          foregroundColor: full || widget.halaqat.isEmpty
              ? AppColors.textMuted
              : AppColors.black,
          icon: const Icon(Icons.add),
          label: Text(
            full ? t('tahfeez.sessionLimit') : t('tahfeez.addSession'),
          ),
        ),
      ),
    );
  }

  Widget _dayStrip() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: const BoxDecoration(
        color: AppColors.blackCard,
        border: Border(bottom: BorderSide(color: AppColors.goldBorder)),
      ),
      child: Row(
        children: [
          for (var d = 0; d < 7; d++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _day = d),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: d == _day ? AppColors.gold : AppColors.blackSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: d == _day ? AppColors.gold : AppColors.goldBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _shortDay(d),
                        style: TextStyle(
                          color: d == _day
                              ? AppColors.black
                              : AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${_ofDay(d).length}',
                        style: TextStyle(
                          color: d == _day
                              ? AppColors.black
                              : AppColors.textMuted,
                          fontSize: 11,
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

  String _shortDay(int d) {
    final full = weekdayName(d);
    // Arabic day names read fine at three letters after the article.
    return full.startsWith('ال') && full.length > 4
        ? full.substring(2, 5)
        : full.substring(0, full.length < 3 ? full.length : 3);
  }

  Widget _sessionCard(TahfeezSession s) {
    final h = _halaqaOf(s.halaqaId);
    return TahfeezCard(
      onTap: h == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SessionEvaluationScreen(
                  session: s,
                  halaqa: h,
                  date: _nextDateOf(s.weekday),
                ),
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

  /// Today if the slot falls today, otherwise the next such weekday — so
  /// opening a Friday slot on a Tuesday assesses the coming Friday.
  DateTime _nextDateOf(int weekday) {
    final now = DateTime.now();
    final delta = (weekday - weekdayOf(now) + 7) % 7;
    return DateTime(now.year, now.month, now.day + delta);
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

  Future<void> _add() async {
    final result = await showModalBottomSheet<TahfeezSession>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _AddSessionSheet(halaqat: widget.halaqat, weekday: _day),
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
      textDirection: TextDirection.rtl,
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
