import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../data/tahfeez_countries.dart';
import '../../l10n/strings.dart';
import '../../services/auth_service.dart';
import '../../services/hidden_teachers.dart';
import '../../services/tahfeez_service.dart';
import 'tahfeez_widgets.dart';

/// Whom a teacher takes on, as the directory filters it: a student ticks any
/// of these and sees every teacher who fits at least one.
enum _Audience { males, females, children }

/// Every approved teacher, with a way to ask any of them — or to type a
/// teacher's code straight in.
///
/// Each teacher is one short row: name, then where they are, what they
/// speak and whom they teach on a single line. Tapping opens the full card.
class TeachersDirectoryScreen extends StatefulWidget {
  /// The reader's current enrolments, keyed by teacher id, so a teacher
  /// already asked shows their status instead of the button.
  final Map<String, Enrollment> enrollments;

  /// The reader's own gender, so teachers who would refuse them are not
  /// listed in the first place.
  final Gender? myGender;

  /// Teachers to show instead of fetching — for previews and tests only.
  @visibleForTesting
  final List<TahfeezProfile>? initialTeachers;

  const TeachersDirectoryScreen({
    super.key,
    required this.enrollments,
    this.myGender,
    this.initialTeachers,
  });

  @override
  State<TeachersDirectoryScreen> createState() =>
      _TeachersDirectoryScreenState();
}

class _TeachersDirectoryScreenState extends State<TeachersDirectoryScreen> {
  List<TahfeezProfile> _teachers = const [];
  late final Map<String, Enrollment> _enrollments = Map.of(widget.enrollments);
  bool _loading = true;
  bool _changed = false;
  String _query = '';
  final _languages = <String>{};
  final _audiences = <_Audience>{};
  final _countries = <String>{};
  final _codeController = TextEditingController();
  bool _joining = false;

  @override
  void initState() {
    super.initState();
    HiddenTeachers.ids.addListener(_onHiddenChanged);
    _load();
  }

  @override
  void dispose() {
    HiddenTeachers.ids.removeListener(_onHiddenChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _onHiddenChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      await HiddenTeachers.load();
      final list = widget.initialTeachers ?? await TahfeezService.teachers();
      if (!mounted) return;
      setState(() {
        _teachers = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNote(context, describeError(e), error: true);
    }
  }

  /// Teachers the reader could ask at all: not refusing their gender, and
  /// not ones they chose to hide. Filters and counts both start from here.
  List<TahfeezProfile> get _eligible => [
    for (final p in _teachers)
      if (p.accepts(widget.myGender) &&
          !HiddenTeachers.ids.value.contains(p.userId))
        p,
  ];

  List<TahfeezProfile> get _hidden => [
    for (final p in _teachers)
      if (HiddenTeachers.ids.value.contains(p.userId)) p,
  ];

  static bool _teaches(TahfeezProfile p, _Audience a) => switch (a) {
    _Audience.males => p.teachesGender != TeachesGender.female,
    _Audience.females => p.teachesGender != TeachesGender.male,
    _Audience.children => p.teachesChildren,
  };

  List<TahfeezProfile> get _visible {
    final q = _query.trim().toLowerCase();
    return _eligible.where((p) {
      if (_languages.isNotEmpty && !p.languages.any(_languages.contains)) {
        return false;
      }
      if (_audiences.isNotEmpty && !_audiences.any((a) => _teaches(p, a))) {
        return false;
      }
      if (_countries.isNotEmpty && !_countries.contains(p.country ?? '')) {
        return false;
      }
      if (q.isEmpty) return true;
      return p.displayName.toLowerCase().contains(q) ||
          (p.city?.toLowerCase().contains(q) ?? false) ||
          (p.country != null &&
              countryName(p.country!).toLowerCase().contains(q)) ||
          (p.teacherCode?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  // ---- filters -------------------------------------------------------------

  Widget _filterBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Row(
        children: [
          Expanded(
            child: _filterButton(
              t('tahfeez.filter.language'),
              _languages.length,
              _pickLanguages,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _filterButton(
              t('tahfeez.filterGender'),
              _audiences.length,
              _pickAudiences,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _filterButton(
              t('tahfeez.filter.country'),
              _countries.length,
              _pickCountries,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterButton(String label, int chosen, VoidCallback onTap) {
    final active = chosen > 0;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? AppColors.goldMuted : AppColors.blackSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? AppColors.gold : AppColors.goldBorder,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                active ? '$label ($chosen)' : label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? AppColors.gold : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              Icons.expand_more,
              size: 16,
              color: active ? AppColors.gold : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickLanguages() async {
    final base = _eligible;
    final options = [
      for (final (code, _) in tahfeezLanguages)
        if (base.any((p) => p.languages.contains(code)))
          (
            code,
            languageName(code),
            base.where((p) => p.languages.contains(code)).length,
          ),
    ];
    final picked = await _pickSheet<String>(
      title: t('tahfeez.filter.language'),
      options: options,
      chosen: _languages,
    );
    if (picked == null) return;
    setState(() {
      _languages
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _pickAudiences() async {
    final base = _eligible;
    final options = [
      for (final a in _Audience.values)
        (
          a,
          t('tahfeez.filter.${a.name}'),
          base.where((p) => _teaches(p, a)).length,
        ),
    ];
    final picked = await _pickSheet<_Audience>(
      title: t('tahfeez.filterGender'),
      options: options,
      chosen: _audiences,
    );
    if (picked == null) return;
    setState(() {
      _audiences
        ..clear()
        ..addAll(picked);
    });
  }

  Future<void> _pickCountries() async {
    final base = _eligible;
    final options = [
      for (final (code, _, _) in tahfeezCountries)
        if (base.any((p) => p.country == code))
          (
            code,
            countryName(code),
            base.where((p) => p.country == code).length,
          ),
    ];
    final picked = await _pickSheet<String>(
      title: t('tahfeez.filter.country'),
      options: options,
      chosen: _countries,
    );
    if (picked == null) return;
    setState(() {
      _countries
        ..clear()
        ..addAll(picked);
    });
  }

  /// A checklist with how many teachers each choice would show. Returns the
  /// new selection, or null if dismissed.
  Future<Set<T>?> _pickSheet<T>({
    required String title,
    required List<(T, String, int)> options,
    required Set<T> chosen,
  }) {
    final working = Set<T>.of(chosen);
    return showModalBottomSheet<Set<T>>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: tahfeezDirection(),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setSheet(working.clear),
                        child: Text(
                          t('tahfeez.filter.clear'),
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                if (options.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      t('tahfeez.noTeachers'),
                      style: const TextStyle(color: AppColors.textMuted),
                    ),
                  ),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final (value, label, count) in options)
                        CheckboxListTile(
                          value: working.contains(value),
                          dense: true,
                          activeColor: AppColors.gold,
                          checkColor: AppColors.black,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            label,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          secondary: Text(
                            '$count',
                            style: const TextStyle(
                              color: AppColors.textGold,
                              fontSize: 13,
                            ),
                          ),
                          onChanged: (v) => setSheet(() {
                            if (v == true) {
                              working.add(value);
                            } else {
                              working.remove(value);
                            }
                          }),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: GoldButton(
                    label: t('tahfeez.filter.apply'),
                    icon: Icons.check,
                    onPressed: () => Navigator.pop(ctx, working),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---- screen --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final hidden = _hidden;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _changed);
      },
      child: Directionality(
        textDirection: tahfeezDirection(),
        child: Scaffold(
          backgroundColor: AppColors.black,
          appBar: AppBar(
            backgroundColor: AppColors.black,
            foregroundColor: AppColors.gold,
            title: Text(t('tahfeez.directory')),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: t('tahfeez.searchTeachers'),
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 13,
                    ),
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
              ),
              _filterBar(),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        children: [
                          if (visible.isEmpty)
                            EmptyNote(
                              icon: Icons.person_search,
                              text: _teachers.isEmpty
                                  ? t('tahfeez.noTeachers')
                                  : t('tahfeez.noTeachersForFilter'),
                            )
                          else
                            for (final p in visible) ...[
                              _teacherRow(p),
                              const SizedBox(height: 6),
                            ],
                          if (hidden.isNotEmpty)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: TextButton.icon(
                                onPressed: () => _showHidden(hidden),
                                icon: const Icon(
                                  Icons.visibility_off_outlined,
                                  size: 16,
                                  color: AppColors.textMuted,
                                ),
                                label: Text(
                                  '${t('tahfeez.hiddenTeachers')} (${hidden.length})',
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          _codeCard(),
                          const SizedBox(height: 30),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One teacher in two lines: who, then where / in what language / for
  /// whom. Everything else waits in the sheet behind a tap.
  Widget _teacherRow(TahfeezProfile p) {
    final photo = p.photoUrl;
    final e = _enrollments[p.userId];
    final meta = [
      if (p.country != null) countryName(p.country!),
      _audienceLabel(p),
      if (p.languages.isNotEmpty) p.languages.map(languageName).join('، '),
      if (p.freeSessions > 0) '${p.freeSessions} ${t('tahfeez.freeSessions')}',
    ].join(' · ');

    return TahfeezCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      onTap: () => _openTeacher(p),
      child: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: AppColors.goldMuted,
            backgroundImage: photo != null ? NetworkImage(photo) : null,
            child: photo == null
                ? const Icon(Icons.person, color: AppColors.gold, size: 20)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _trailing(p, e),
        ],
      ),
    );
  }

  /// Whom the teacher takes on, in the filter's own short words.
  String _audienceLabel(TahfeezProfile p) => [
    for (final a in _Audience.values)
      if (_teaches(p, a)) t('tahfeez.filter.${a.name}'),
  ].join('، ');

  /// The status badge or the ask button, small enough for one row.
  Widget _trailing(TahfeezProfile p, Enrollment? e) {
    if (e == null || e.status == EnrollmentStatus.rejected) {
      return _smallButton(
        icon: Icons.person_add_alt_1,
        label: t('tahfeez.requestJoin'),
        onTap: () => _request(p),
      );
    }
    final color = e.isActive ? AppColors.success : AppColors.goldLight;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          e.isPending
              ? Icons.hourglass_top
              : e.isActive
              ? Icons.check_circle
              : Icons.info_outline,
          size: 18,
          color: color,
        ),
        const SizedBox(height: 2),
        Text(
          t('tahfeez.status.${e.isExpired ? 'expired' : e.status.name}'),
          style: TextStyle(color: color, fontSize: 10),
        ),
      ],
    );
  }

  Widget _smallButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.black),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.black,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---- the full card -------------------------------------------------------

  Future<void> _openTeacher(TahfeezProfile p) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: tahfeezDirection(),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: _teacherDetails(ctx, p, () => setSheet(() {})),
            ),
          ),
        ),
      ),
    );
  }

  Widget _teacherDetails(
    BuildContext ctx,
    TahfeezProfile p,
    VoidCallback refresh,
  ) {
    final photo = p.photoUrl;
    final e = _enrollments[p.userId];
    final place = [
      if (p.city != null) p.city!,
      if (p.country != null) countryName(p.country!),
    ].join('، ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.goldMuted,
              backgroundImage: photo != null ? NetworkImage(photo) : null,
              child: photo == null
                  ? const Icon(Icons.person, color: AppColors.gold, size: 30)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.displayName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (place.isNotEmpty)
                    Text(
                      place,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            if (p.teacherCode != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.goldMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.teacherCode!,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 13,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        if (p.bio != null) ...[
          const SizedBox(height: 12),
          Text(
            p.bio!,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              height: 1.6,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final code in p.languages)
              _chip(Icons.translate, languageName(code)),
            _chip(Icons.wc, t('tahfeez.teaches.${p.teachesGender.name}')),
            if (p.teachesChildren)
              _chip(Icons.child_care, t('tahfeez.teaches.children')),
            _chip(Icons.event_repeat, t('tahfeez.plan.${p.planPeriod.name}')),
            if (p.freeSessions > 0)
              _chip(
                Icons.card_giftcard,
                '${p.freeSessions} ${t('tahfeez.freeSessions')}',
              ),
            if (p.priceNote != null)
              _chip(Icons.payments_outlined, p.priceNote!),
          ],
        ),
        const SizedBox(height: 16),
        if (e == null || e.status == EnrollmentStatus.rejected)
          GoldButton(
            label: t('tahfeez.requestJoin'),
            icon: Icons.person_add_alt_1,
            onPressed: () async {
              await _request(p);
              refresh();
            },
          )
        else
          Row(
            children: [
              Icon(
                e.isPending
                    ? Icons.hourglass_top
                    : e.isActive
                    ? Icons.check_circle
                    : Icons.info_outline,
                size: 18,
                color: e.isActive ? AppColors.success : AppColors.goldLight,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  t(
                    'tahfeez.status.${e.isExpired ? 'expired' : e.status.name}',
                  ),
                  style: TextStyle(
                    color: e.isActive ? AppColors.success : AppColors.goldLight,
                    fontSize: 13,
                  ),
                ),
              ),
              if (e.isPending)
                TextButton(
                  onPressed: () async {
                    await _cancel(p, e);
                    refresh();
                  },
                  child: Text(
                    t('tahfeez.cancelRequest'),
                    style: const TextStyle(color: AppColors.error),
                  ),
                ),
            ],
          ),
        if (e == null || e.status == EnrollmentStatus.rejected) ...[
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () async {
                await HiddenTeachers.set(p.userId, true);
                if (!ctx.mounted || !mounted) return;
                Navigator.pop(ctx);
                showNote(context, t('tahfeez.teacherHidden'));
              },
              icon: const Icon(
                Icons.visibility_off_outlined,
                size: 16,
                color: AppColors.textMuted,
              ),
              label: Text(
                t('tahfeez.hideTeacher'),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.blackSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.gold),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showHidden(List<TahfeezProfile> hidden) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: tahfeezDirection(),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    t('tahfeez.hiddenTeachers'),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              for (final p in hidden)
                ListTile(
                  dense: true,
                  title: Text(
                    p.displayName,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await HiddenTeachers.set(p.userId, false);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: Text(
                      t('tahfeez.unhide'),
                      style: const TextStyle(color: AppColors.gold),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ---- actions -------------------------------------------------------------

  Future<void> _request(TahfeezProfile p) async {
    final note = await promptText(
      context,
      title: '${t('tahfeez.requestJoin')} — ${p.displayName}',
      hint: t('tahfeez.requestJoinNote'),
      confirmLabel: t('tahfeez.requestJoin'),
      maxLines: 2,
    );
    if (note == null || !mounted) return;
    try {
      await TahfeezService.requestEnrollment(p.userId, note);
      if (!mounted) return;
      showNote(context, '${t('tahfeez.requestJoinSent')} ${p.displayName}');
      _changed = true;
      await _refreshEnrollment(p.userId);
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _cancel(TahfeezProfile p, Enrollment e) async {
    final ok = await confirmDialog(
      context,
      message: '${t('tahfeez.cancelRequest')} — ${p.displayName}؟',
      confirmLabel: t('tahfeez.cancelRequest'),
    );
    if (!ok || !mounted) return;
    try {
      await TahfeezService.cancelEnrollment(e.id);
      if (!mounted) return;
      _changed = true;
      setState(() => _enrollments.remove(p.userId));
      showNote(context, t('tahfeez.requestCancelled'));
    } catch (err) {
      if (mounted) showNote(context, describeError(err), error: true);
    }
  }

  /// Fetches the real row after a request, so cancelling it has an id to
  /// point at rather than a placeholder.
  Future<void> _refreshEnrollment(String teacherId) async {
    final me = AuthService.user.value?.id;
    try {
      final all = await TahfeezService.enrollments();
      final mine = all.where(
        (e) => e.teacherId == teacherId && e.studentId == me,
      );
      if (!mounted) return;
      setState(() {
        if (mine.isNotEmpty) _enrollments[teacherId] = mine.first;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _enrollments[teacherId] = Enrollment(
          id: '',
          teacherId: teacherId,
          studentId: me ?? '',
          status: EnrollmentStatus.pending,
          freeSessionsLeft: 0,
          paid: false,
          createdAt: DateTime.now(),
        );
      });
    }
  }

  Widget _codeCard() {
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('tahfeez.joinByCode'),
            style: const TextStyle(
              color: AppColors.textGold,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    letterSpacing: 3,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: t('tahfeez.teacherCodeHint'),
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      letterSpacing: 0,
                      fontWeight: FontWeight.normal,
                    ),
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
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _joining ? null : _joinByCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  t('tahfeez.requestJoin'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _joinByCode() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _joining = true);
    try {
      final name = await TahfeezService.requestEnrollmentByCode(code, '');
      if (!mounted) return;
      _codeController.clear();
      FocusScope.of(context).unfocus();
      showNote(context, '${t('tahfeez.requestJoinSent')} $name');
      _changed = true;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }
}
