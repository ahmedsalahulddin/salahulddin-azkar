import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../data/quran_data.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';
import '../services/custom_reminders.dart';
import '../services/prayer_service.dart';

/// Weekdays in the order an Arabic week reads, Saturday first.
const _weekOrder = [6, 7, 1, 2, 3, 4, 5];

/// The adhkar a reminder can point at — the everyday sets, not the deceased
/// page, which has its own screen and is not a daily practice.
const _adhkarChoices = [
  'morning',
  'evening',
  'after-prayer',
  'sleep',
  'travel',
  'ruqyah',
];

String _dayName(int weekday) => t('myrem.day$weekday');

String _timeText(int minutes) =>
    PrayerService.formatTime(DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60));

String _surahName(List<SurahInfo> surahs, int? number) {
  final info = surahs.where((s) => s.number == number).firstOrNull;
  if (info == null) return '$number';
  return AppLocale.code == 'ar' ? info.name : info.nameEn;
}

String _reminderTitle(CustomReminder r, List<SurahInfo> surahs) =>
    r.kind == ReminderKind.surah
    ? '${t('myrem.surah')} ${_surahName(surahs, r.surah)}'
    : t('adhkar.cat.${r.adhkarId}');

String _daysText(Set<int> days) => days.length == 7
    ? t('myrem.everyDay')
    : [
        for (final d in _weekOrder)
          if (days.contains(d)) _dayName(d),
      ].join(AppLocale.isRtl ? '، ' : ', ');

/// The reader's own reminders: a surah or a set of adhkar, on the days and at
/// the times they choose. Lives under Account → Reminders.
class CustomRemindersScreen extends StatefulWidget {
  const CustomRemindersScreen({super.key});

  @override
  State<CustomRemindersScreen> createState() => _CustomRemindersScreenState();
}

class _CustomRemindersScreenState extends State<CustomRemindersScreen> {
  List<SurahInfo> _surahs = const [];

  @override
  void initState() {
    super.initState();
    QuranService.index().then((s) {
      if (mounted) setState(() => _surahs = s);
    });
  }

  Future<void> _open([CustomReminder? r, CustomReminder? template]) =>
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReminderEditorScreen(reminder: r, template: template),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(t('myrem.title')),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: ValueListenableBuilder<List<CustomReminder>>(
          valueListenable: CustomReminders.list,
          builder: (context, list, _) {
            // Each suggestion is a card of its own, switched off until the
            // reader turns it on; a reminder already set for the same surah
            // or adhkar takes its place. Everything else follows.
            final used = <int>{};
            final presetCards = <Widget>[];
            for (final p in _presets) {
              final existing = list
                  .where((r) => !used.contains(r.id) && p.matches(r))
                  .firstOrNull;
              if (existing != null) {
                used.add(existing.id);
                presetCards.add(_card(existing));
              } else {
                presetCards.add(_suggestionCard(p.template));
              }
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
              children: [
                Text(
                  t('myrem.sub'),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12.5,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 14),
                ...presetCards,
                for (final r in list)
                  if (!used.contains(r.id)) _card(r),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _open(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: AppColors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.add_alarm),
                    label: Text(t('myrem.add')),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Morning adhkar, evening adhkar, Al-Mulk, Al-Kahf — in that order.
  static final _presets = [
    (
      matches: (CustomReminder r) =>
          r.kind == ReminderKind.adhkar && r.adhkarId == 'morning',
      template: const CustomReminder(
        id: -1,
        kind: ReminderKind.adhkar,
        adhkarId: 'morning',
        days: {1, 2, 3, 4, 5, 6, 7},
        times: [6 * 60],
        enabled: false,
      ),
    ),
    (
      matches: (CustomReminder r) =>
          r.kind == ReminderKind.adhkar && r.adhkarId == 'evening',
      template: const CustomReminder(
        id: -1,
        kind: ReminderKind.adhkar,
        adhkarId: 'evening',
        days: {1, 2, 3, 4, 5, 6, 7},
        times: [17 * 60],
        enabled: false,
      ),
    ),
    (
      matches: (CustomReminder r) =>
          r.kind == ReminderKind.surah && r.surah == 67,
      template: const CustomReminder(
        id: -1,
        kind: ReminderKind.surah,
        surah: 67,
        days: {1, 2, 3, 4, 5, 6, 7},
        times: [21 * 60 + 30],
        enabled: false,
      ),
    ),
    (
      matches: (CustomReminder r) =>
          r.kind == ReminderKind.surah && r.surah == 18,
      template: const CustomReminder(
        id: -1,
        kind: ReminderKind.surah,
        surah: 18,
        days: {5},
        times: [9 * 60],
        enabled: false,
      ),
    ),
  ];

  /// A suggestion not set up yet: looks like a reminder that is off. The
  /// switch turns it on with its usual days and time; a tap opens it to
  /// change them first.
  Widget _suggestionCard(CustomReminder template) => _card(
    template,
    onToggle: (on) async {
      if (!on) return;
      await CustomReminders.save(
        template.copyWithId(CustomReminders.nextId()).copyWith(enabled: true),
      );
    },
    onTap: () => _open(null, template.copyWith(enabled: true)),
  );

  Widget _card(
    CustomReminder r, {
    ValueChanged<bool>? onToggle,
    VoidCallback? onTap,
  }) {
    final times = [...r.times]..sort();
    return GestureDetector(
      onTap: onTap ?? () => _open(r),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: r.enabled ? AppColors.goldBorder : AppColors.blackSurface,
          ),
        ),
        child: Row(
          children: [
            Icon(
              r.kind == ReminderKind.surah
                  ? Icons.menu_book_outlined
                  : Icons.auto_awesome_outlined,
              color: r.enabled ? AppColors.gold : AppColors.textMuted,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _reminderTitle(r, _surahs),
                    style: TextStyle(
                      color: r.enabled
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _daysText(r.days),
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    times.map(_timeText).join('  ·  '),
                    textDirection: AppLocale.direction,
                    style: const TextStyle(
                      color: AppColors.textGold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: r.enabled,
              activeThumbColor: AppColors.gold,
              onChanged:
                  onToggle ??
                  (v) => CustomReminders.save(r.copyWith(enabled: v)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Creates a reminder, or edits [reminder].
class ReminderEditorScreen extends StatefulWidget {
  final CustomReminder? reminder;

  /// Starting values for a new reminder (a suggestion not yet switched on).
  final CustomReminder? template;

  const ReminderEditorScreen({super.key, this.reminder, this.template});

  @override
  State<ReminderEditorScreen> createState() => _ReminderEditorScreenState();
}

class _ReminderEditorScreenState extends State<ReminderEditorScreen> {
  late final CustomReminder? _start = widget.reminder ?? widget.template;
  late ReminderKind _kind = _start?.kind ?? ReminderKind.surah;
  late int _surah = _start?.surah ?? 18;
  late String _adhkar = _start?.adhkarId ?? 'morning';
  late final Set<int> _days = {...?_start?.days};
  late final List<int> _times = [...?_start?.times];
  List<SurahInfo> _surahs = const [];

  bool get _editing => widget.reminder != null;
  bool get _valid => _days.isNotEmpty && _times.isNotEmpty;

  @override
  void initState() {
    super.initState();
    QuranService.index().then((s) {
      if (mounted) setState(() => _surahs = s);
    });
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    if (_times.contains(m)) return;
    setState(
      () => _times
        ..add(m)
        ..sort(),
    );
  }

  Future<void> _pickSurah() async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blackCard,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      builder: (_) => _SurahPicker(surahs: _surahs),
    );
    if (chosen != null) setState(() => _surah = chosen);
  }

  Future<void> _save() async {
    if (!_valid) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('myrem.needDaysTimes'))));
      return;
    }
    await CustomReminders.save(
      CustomReminder(
        id: widget.reminder?.id ?? CustomReminders.nextId(),
        kind: _kind,
        surah: _kind == ReminderKind.surah ? _surah : null,
        adhkarId: _kind == ReminderKind.adhkar ? _adhkar : null,
        days: _days,
        times: _times,
        enabled: widget.reminder?.enabled ?? true,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(t('myrem.saved'))));
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.blackCard,
        content: Text(
          t('myrem.deleteConfirm'),
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('myrem.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t('myrem.delete'),
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (yes != true) return;
    await CustomReminders.remove(widget.reminder!.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocale.direction,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(_editing ? t('myrem.edit') : t('myrem.add')),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            if (_editing)
              IconButton(
                tooltip: t('myrem.delete'),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _label(t('myrem.what')),
            SegmentedButton<ReminderKind>(
              segments: [
                ButtonSegment(
                  value: ReminderKind.surah,
                  label: Text(t('myrem.surah')),
                  icon: const Icon(Icons.menu_book_outlined),
                ),
                ButtonSegment(
                  value: ReminderKind.adhkar,
                  label: Text(t('myrem.adhkar')),
                  icon: const Icon(Icons.auto_awesome_outlined),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (s) => setState(() => _kind = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.goldMuted,
                selectedForegroundColor: AppColors.gold,
                foregroundColor: AppColors.textSecondary,
                side: const BorderSide(color: AppColors.goldBorder),
              ),
            ),
            const SizedBox(height: 12),
            if (_kind == ReminderKind.surah)
              ListTile(
                onTap: _surahs.isEmpty ? null : _pickSurah,
                tileColor: AppColors.blackCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: const BorderSide(color: AppColors.goldBorder),
                ),
                leading: const Icon(Icons.menu_book, color: AppColors.gold),
                title: Text(
                  '${t('myrem.surah')} ${_surahName(_surahs, _surah)}',
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  t('myrem.pickSurah'),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                trailing: const Icon(
                  Icons.unfold_more,
                  color: AppColors.textMuted,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in _adhkarChoices)
                    ChoiceChip(
                      label: Text(t('adhkar.cat.$id')),
                      selected: _adhkar == id,
                      onSelected: (_) => setState(() => _adhkar = id),
                      selectedColor: AppColors.goldMuted,
                      backgroundColor: AppColors.blackCard,
                      side: const BorderSide(color: AppColors.goldBorder),
                      labelStyle: TextStyle(
                        color: _adhkar == id
                            ? AppColors.gold
                            : AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(child: _label(t('myrem.days'))),
                TextButton(
                  onPressed: () => setState(() {
                    if (_days.length == 7) {
                      _days.clear();
                    } else {
                      _days.addAll(_weekOrder);
                    }
                  }),
                  child: Text(t('myrem.everyDay')),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in _weekOrder)
                  FilterChip(
                    label: Text(_dayName(d)),
                    selected: _days.contains(d),
                    onSelected: (on) =>
                        setState(() => on ? _days.add(d) : _days.remove(d)),
                    selectedColor: AppColors.goldMuted,
                    checkmarkColor: AppColors.gold,
                    backgroundColor: AppColors.blackCard,
                    side: const BorderSide(color: AppColors.goldBorder),
                    labelStyle: TextStyle(
                      color: _days.contains(d)
                          ? AppColors.gold
                          : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            _label(t('myrem.times')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _times)
                  InputChip(
                    label: Text(
                      _timeText(m),
                      textDirection: AppLocale.direction,
                    ),
                    onDeleted: () => setState(() => _times.remove(m)),
                    deleteIconColor: AppColors.textMuted,
                    backgroundColor: AppColors.goldMuted,
                    side: const BorderSide(color: AppColors.goldBorder),
                    labelStyle: const TextStyle(color: AppColors.textGold),
                  ),
                if (_times.length < CustomReminder.maxTimes)
                  ActionChip(
                    avatar: const Icon(
                      Icons.add,
                      size: 16,
                      color: AppColors.gold,
                    ),
                    label: Text(t('myrem.addTime')),
                    onPressed: _addTime,
                    backgroundColor: AppColors.blackCard,
                    side: const BorderSide(color: AppColors.goldBorder),
                    labelStyle: const TextStyle(color: AppColors.textPrimary),
                  ),
              ],
            ),
            const SizedBox(height: 30),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                backgroundColor: _valid
                    ? AppColors.gold
                    : AppColors.blackSurface,
                foregroundColor: _valid ? AppColors.black : AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(t('myrem.save')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        color: AppColors.gold,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _SurahPicker extends StatefulWidget {
  final List<SurahInfo> surahs;

  const _SurahPicker({required this.surahs});

  @override
  State<_SurahPicker> createState() => _SurahPickerState();
}

class _SurahPickerState extends State<_SurahPicker> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty
        ? widget.surahs
        : widget.surahs
              .where(
                (s) =>
                    s.name.contains(q) ||
                    s.nameEn.toLowerCase().contains(q) ||
                    '${s.number}' == q,
              )
              .toList();
    return Directionality(
      textDirection: AppLocale.direction,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: t('myrem.searchSurah'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search, color: AppColors.gold),
                  filled: true,
                  fillColor: AppColors.black,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: shown.length,
                itemBuilder: (_, i) {
                  final s = shown[i];
                  return ListTile(
                    onTap: () => Navigator.pop(context, s.number),
                    leading: Text(
                      '${s.number}',
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                    title: Text(
                      s.name,
                      style: const TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      s.nameEn,
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
