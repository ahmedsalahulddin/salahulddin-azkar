import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../constants/theme.dart';
import '../../data/quran_data.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
import 'tahfeez_widgets.dart';

/// One session on one date: every student in the circle, and whether the
/// teacher has assessed them yet.
class SessionEvaluationScreen extends StatefulWidget {
  final TahfeezSession session;
  final Halaqa halaqa;
  final DateTime date;

  const SessionEvaluationScreen({
    super.key,
    required this.session,
    required this.halaqa,
    required this.date,
  });

  @override
  State<SessionEvaluationScreen> createState() =>
      _SessionEvaluationScreenState();
}

class _SessionEvaluationScreenState extends State<SessionEvaluationScreen> {
  late DateTime _date = DateTime(
    widget.date.year,
    widget.date.month,
    widget.date.day,
  );
  List<HalaqaMember> _members = const [];
  Map<String, Evaluation> _byStudent = const {};
  List<SurahInfo> _surahs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        TahfeezService.members(widget.halaqa.id),
        TahfeezService.evaluationsFor(
          sessionId: widget.session.id,
          date: _date,
        ),
        QuranService.index(),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<HalaqaMember>;
        _byStudent = {
          for (final e in results[1] as List<Evaluation>) e.studentId: e,
        };
        _surahs = results[2] as List<SurahInfo>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
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
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
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
              Text(widget.halaqa.name, style: const TextStyle(fontSize: 17)),
              Text(
                '${weekdayName(s.weekday)} · ${formatTime(s.start)} – ${formatTime(s.end)}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.blackCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.goldBorder),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      color: AppColors.gold,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${t('tahfeez.date')}: ${formatDate(_date)}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.edit,
                      color: AppColors.textMuted,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    )
                  : _members.isEmpty
                  ? EmptyNote(
                      icon: Icons.groups_outlined,
                      text: t('tahfeez.noStudents'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _members.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _memberCard(_members[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _memberCard(HalaqaMember m) {
    final e = _byStudent[m.studentId];
    final photo = m.profile?.photoUrl;
    return TahfeezCard(
      onTap: () async {
        final saved = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => EvaluationEditorScreen(
              session: widget.session,
              date: _date,
              member: m,
              existing: e,
              surahs: _surahs,
            ),
          ),
        );
        if (saved == true) _load();
      },
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
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
                const SizedBox(height: 3),
                if (e == null)
                  Text(
                    t('tahfeez.notEvaluated'),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  )
                else
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final k in EvalPointKind.values)
                        if (pointOf(e, k) != null)
                          _gradeChip(pointOf(e, k)!.grade, k),
                    ],
                  ),
              ],
            ),
          ),
          Icon(
            e == null ? Icons.radio_button_unchecked : Icons.check_circle,
            color: e == null ? AppColors.textMuted : AppColors.success,
            size: 22,
          ),
        ],
      ),
    );
  }

  Widget _gradeChip(EvalGrade g, EvalPointKind k) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: gradeColor(g).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(pointIcon(k), size: 11, color: gradeColor(g)),
          const SizedBox(width: 3),
          Text(
            gradeLabel(g),
            style: TextStyle(color: gradeColor(g), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _PointDraft {
  bool enabled = false;
  int fromSurah = 1;
  int fromAyah = 1;
  int toSurah = 1;
  int toAyah = 7;
  EvalGrade grade = EvalGrade.good;
  final note = TextEditingController();
  final fromAyahField = TextEditingController(text: '1');
  final toAyahField = TextEditingController(text: '7');

  void adopt(EvalPoint p) {
    enabled = true;
    fromSurah = p.fromSurah;
    fromAyah = p.fromAyah;
    toSurah = p.toSurah;
    toAyah = p.toAyah;
    grade = p.grade;
    note.text = p.note ?? '';
    fromAyahField.text = '$fromAyah';
    toAyahField.text = '$toAyah';
  }

  void dispose() {
    note.dispose();
    fromAyahField.dispose();
    toAyahField.dispose();
  }
}

/// The three points for one student, two of which must be filled in.
class EvaluationEditorScreen extends StatefulWidget {
  final TahfeezSession session;
  final DateTime date;
  final HalaqaMember member;
  final Evaluation? existing;
  final List<SurahInfo> surahs;

  const EvaluationEditorScreen({
    super.key,
    required this.session,
    required this.date,
    required this.member,
    required this.existing,
    required this.surahs,
  });

  @override
  State<EvaluationEditorScreen> createState() => _EvaluationEditorScreenState();
}

class _EvaluationEditorScreenState extends State<EvaluationEditorScreen> {
  final _drafts = {for (final k in EvalPointKind.values) k: _PointDraft()};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      for (final k in EvalPointKind.values) {
        final p = pointOf(e, k);
        if (p != null) _drafts[k]!.adopt(p);
      }
    } else {
      // A fresh sheet starts with the two everyday points switched on.
      _drafts[EvalPointKind.review]!.enabled = true;
      _drafts[EvalPointKind.newHifz]!.enabled = true;
    }
  }

  @override
  void dispose() {
    for (final d in _drafts.values) {
      d.dispose();
    }
    super.dispose();
  }

  int _ayahCount(int surah) {
    for (final s in widget.surahs) {
      if (s.number == surah) return s.ayahCount;
    }
    return 286;
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.member.name, style: const TextStyle(fontSize: 17)),
              Text(
                formatDate(widget.date),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
          children: [
            Text(
              t('tahfeez.minTwoPoints'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 10),
            for (final k in EvalPointKind.values) ...[
              _pointCard(k),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
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

  Widget _pointCard(EvalPointKind k) {
    final d = _drafts[k]!;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: d.enabled ? AppColors.blackCard : AppColors.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: d.enabled ? AppColors.gold : AppColors.goldBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                pointIcon(k),
                color: d.enabled ? AppColors.gold : AppColors.textMuted,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pointLabel(k),
                  style: TextStyle(
                    color: d.enabled
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: d.enabled,
                activeThumbColor: AppColors.gold,
                activeTrackColor: AppColors.goldMuted,
                onChanged: (v) => setState(() => d.enabled = v),
              ),
            ],
          ),
          if (d.enabled) ...[
            const SizedBox(height: 10),
            _rangeRow(d, from: true),
            const SizedBox(height: 8),
            _rangeRow(d, from: false),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final g in EvalGrade.values)
                  ChoiceChip(
                    label: Text(gradeLabel(g)),
                    selected: d.grade == g,
                    selectedColor: gradeColor(g).withValues(alpha: 0.25),
                    backgroundColor: AppColors.blackSurface,
                    side: BorderSide(
                      color: d.grade == g
                          ? gradeColor(g)
                          : AppColors.goldBorder,
                    ),
                    labelStyle: TextStyle(
                      color: d.grade == g ? gradeColor(g) : AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: d.grade == g
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    showCheckmark: false,
                    onSelected: (_) => setState(() => d.grade = g),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: d.note,
              maxLines: 2,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
              decoration: InputDecoration(
                hintText: t('tahfeez.noteHint'),
                hintStyle: const TextStyle(color: AppColors.textMuted),
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
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rangeRow(_PointDraft d, {required bool from}) {
    final surah = from ? d.fromSurah : d.toSurah;
    final field = from ? d.fromAyahField : d.toAyahField;
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            from ? t('tahfeez.fromSurah') : t('tahfeez.toSurah'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ),
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<int>(
            initialValue: surah,
            isDense: true,
            isExpanded: true,
            dropdownColor: AppColors.blackSurface,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _dec(),
            items: [
              for (final s in widget.surahs)
                DropdownMenuItem(
                  value: s.number,
                  child: Text('${s.number}. ${s.name}'),
                ),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                if (from) {
                  d.fromSurah = v;
                  if (d.toSurah < v) d.toSurah = v;
                } else {
                  d.toSurah = v;
                  if (d.fromSurah > v) d.fromSurah = v;
                }
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 74,
          child: TextField(
            controller: field,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: _dec().copyWith(
              prefixText: '${t('tahfeez.ayah')} ',
              prefixStyle: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _dec() => InputDecoration(
    isDense: true,
    filled: true,
    fillColor: AppColors.blackSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.goldBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppColors.goldBorder),
    ),
  );

  EvalPoint? _pointFrom(_PointDraft d) {
    if (!d.enabled) return null;
    final fromAyah = (int.tryParse(d.fromAyahField.text) ?? 1).clamp(
      1,
      _ayahCount(d.fromSurah),
    );
    final toAyah = (int.tryParse(d.toAyahField.text) ?? 1).clamp(
      1,
      _ayahCount(d.toSurah),
    );
    return EvalPoint(
      fromSurah: d.fromSurah,
      fromAyah: fromAyah,
      toSurah: d.toSurah,
      toAyah: toAyah,
      grade: d.grade,
      note: d.note.text.trim(),
    );
  }

  Future<void> _save() async {
    final enabled = _drafts.values.where((d) => d.enabled).length;
    if (enabled < 2) {
      showNote(context, t('tahfeez.minTwoPoints'), error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await TahfeezService.saveEvaluation(
        Evaluation(
          sessionId: widget.session.id,
          studentId: widget.member.studentId,
          date: widget.date,
          review: _pointFrom(_drafts[EvalPointKind.review]!),
          newHifz: _pointFrom(_drafts[EvalPointKind.newHifz]!),
          tafsir: _pointFrom(_drafts[EvalPointKind.tafsir]!),
        ),
      );
      if (!mounted) return;
      showNote(context, t('tahfeez.saved'));
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showNote(context, describeError(e), error: true);
      }
    }
  }
}
