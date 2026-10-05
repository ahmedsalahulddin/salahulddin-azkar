import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
import 'tahfeez_widgets.dart';

/// The week as the reader's calendar starts it: Saturday first, then Sunday
/// (0) through Friday (5), in the sessions table's numbering.
const availabilityWeekOrder = [6, 0, 1, 2, 3, 4, 5];

String minutesLabel(int minutes) =>
    formatTime(TimeOfDay(hour: minutes ~/ 60 % 24, minute: minutes % 60));

/// "Sat 4:00 PM – 8:00 PM, Mon 9:00 AM – 12:00 PM" grouped by day, for the
/// directory and the teacher's own summary line.
List<(int, List<AvailabilitySlot>)> availabilityByDay(
  List<AvailabilitySlot> slots,
) => [
  for (final d in availabilityWeekOrder)
    if (slots.any((s) => s.weekday == d))
      (
        d,
        slots.where((s) => s.weekday == d).toList()
          ..sort((a, b) => a.from.compareTo(b.from)),
      ),
];

/// Where a teacher says when they are free to teach: switch a day on, then
/// give it one or more time ranges. Students see it on the teacher's card.
class AvailabilityScreen extends StatefulWidget {
  final List<AvailabilitySlot> initial;

  /// Skips the network on save — for previews and tests only.
  @visibleForTesting
  final bool offline;

  const AvailabilityScreen({
    super.key,
    required this.initial,
    this.offline = false,
  });

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  late final List<AvailabilitySlot> _slots = List.of(widget.initial);
  bool _saving = false;

  static const _maxPerDay = 4;

  List<AvailabilitySlot> _of(int day) =>
      _slots.where((s) => s.weekday == day).toList()
        ..sort((a, b) => a.from.compareTo(b.from));

  void _toggleDay(int day, bool on) {
    setState(() {
      if (on) {
        _slots.add(AvailabilitySlot(weekday: day, from: 16 * 60, to: 20 * 60));
      } else {
        _slots.removeWhere((s) => s.weekday == day);
      }
    });
  }

  Future<TimeOfDay?> _time(int minutes, String help) => showTimePicker(
    context: context,
    helpText: help,
    initialTime: TimeOfDay(hour: minutes ~/ 60 % 24, minute: minutes % 60),
  );

  /// Asks for the start, then the end. Null if either is cancelled or the
  /// end does not come after the start.
  Future<AvailabilitySlot?> _askRange(int day, AvailabilitySlot? from) async {
    final start = await _time(from?.from ?? 16 * 60, t('tahfeez.avail.from'));
    if (start == null || !mounted) return null;
    final startMin = start.hour * 60 + start.minute;
    final end = await _time(
      from?.to ?? (startMin + 120).clamp(0, 23 * 60 + 59),
      t('tahfeez.avail.to'),
    );
    if (end == null || !mounted) return null;
    var endMin = end.hour * 60 + end.minute;
    if (endMin == 0) endMin = 1440; // "until midnight"
    if (endMin <= startMin) {
      showNote(context, t('tahfeez.avail.badRange'), error: true);
      return null;
    }
    return AvailabilitySlot(weekday: day, from: startMin, to: endMin);
  }

  Future<void> _add(int day) async {
    final slot = await _askRange(day, null);
    if (slot != null) setState(() => _slots.add(slot));
  }

  Future<void> _edit(AvailabilitySlot old) async {
    final slot = await _askRange(old.weekday, old);
    if (slot == null) return;
    setState(() {
      _slots
        ..remove(old)
        ..add(slot);
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (!widget.offline) await TahfeezService.setAvailability(_slots);
      if (!mounted) return;
      showNote(context, t('tahfeez.avail.saved'));
      Navigator.pop(context, _slots);
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
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
          title: Text(t('tahfeez.avail.title')),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              t('tahfeez.avail.sub'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 12),
            for (final day in availabilityWeekOrder) ...[
              _dayCard(day),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 8),
            GoldButton(
              label: t('tahfeez.avail.save'),
              icon: Icons.check,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCard(int day) {
    final slots = _of(day);
    final on = slots.isNotEmpty;
    return TahfeezCard(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  weekdayName(day),
                  style: TextStyle(
                    color: on ? AppColors.gold : AppColors.textSecondary,
                    fontSize: 15,
                    fontWeight: on ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Switch(
                value: on,
                activeThumbColor: AppColors.gold,
                onChanged: (v) => _toggleDay(day, v),
              ),
            ],
          ),
          if (on)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final s in slots)
                  InputChip(
                    label: Text(
                      '${minutesLabel(s.from)} – ${minutesLabel(s.to)}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: AppColors.goldMuted,
                    side: const BorderSide(color: AppColors.goldBorder),
                    deleteIconColor: AppColors.textMuted,
                    onPressed: () => _edit(s),
                    onDeleted: () => setState(() => _slots.remove(s)),
                  ),
                if (slots.length < _maxPerDay)
                  ActionChip(
                    avatar: const Icon(
                      Icons.add,
                      size: 16,
                      color: AppColors.gold,
                    ),
                    label: Text(
                      t('tahfeez.avail.addRange'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    backgroundColor: AppColors.blackSurface,
                    side: const BorderSide(color: AppColors.goldBorder),
                    onPressed: () => _add(day),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
