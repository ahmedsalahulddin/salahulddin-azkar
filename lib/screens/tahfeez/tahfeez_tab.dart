import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../constants/theme.dart';
import '../../data/tahfeez_countries.dart';
import '../../l10n/strings.dart';
import '../../services/app_locale.dart';
import '../../services/auth_service.dart';
import '../../services/tahfeez_service.dart';
import '../../widgets/sign_in_buttons.dart';
import '../account_screen.dart' show UserAvatar;
import 'availability_screen.dart';
import 'chat_screen.dart';
import 'enrollments_screen.dart';
import 'halaqa_screen.dart';
import 'teacher_profile_screen.dart';
import 'teachers_directory_screen.dart';
import 'schedule_screen.dart';
import 'session_evaluation_screen.dart';
import 'student_halaqa_screen.dart';
import 'student_progress_screen.dart';
import 'tahfeez_widgets.dart';

/// Everything the module has to offer the signed-in reader, whichever side
/// of the circle they sit on: a teacher's circles, timetable and today's
/// sessions; a student's circles and record; and the two doors in — joining
/// by code, or asking to be approved as a teacher.
class TahfeezTab extends StatefulWidget {
  const TahfeezTab({
    super.key,
    this.initialProfile,
    this.initialHalaqat = const [],
    this.initialSessions = const [],
    this.initialEnrollments = const [],
    this.initialTeachers,
  });

  /// Skips the network load and renders straight from this — for previews
  /// and tests only. The lists below go with it.
  @visibleForTesting
  final TahfeezProfile? initialProfile;
  @visibleForTesting
  final List<Halaqa> initialHalaqat;
  @visibleForTesting
  final List<TahfeezSession> initialSessions;
  @visibleForTesting
  final List<Enrollment> initialEnrollments;
  @visibleForTesting
  final List<TahfeezProfile>? initialTeachers;

  @override
  State<TahfeezTab> createState() => _TahfeezTabState();
}

/// The four parts of the tab, switched between under the profile card.
enum _Section { halaqat, sessions, teachers, directory }

class _TahfeezTabState extends State<TahfeezTab> {
  TahfeezProfile? _profile;
  List<Halaqa> _halaqat = const [];
  List<TahfeezSession> _sessions = const [];
  List<Enrollment> _enrollments = const [];
  bool _pendingRequest = false;
  bool _loading = false;
  bool _failed = false;
  bool _signingIn = false;
  bool _joining = false;
  final _codeController = TextEditingController();

  /// Which part is showing; remembered between visits. Null until read.
  _Section? _section;
  static const _sectionKey = 'tahfeez_section';
  bool _askedCountry = false;

  /// A preview with no server behind it.
  bool get _offline => widget.initialProfile != null;

  @override
  void initState() {
    super.initState();
    AuthService.user.addListener(_onAuthChanged);
    _restoreSection();
    if (widget.initialProfile != null) {
      _profile = widget.initialProfile;
      _halaqat = widget.initialHalaqat;
      _sessions = widget.initialSessions;
      _enrollments = widget.initialEnrollments;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _askCountryOnce(_profile!),
      );
    } else {
      _load();
    }
  }

  Future<void> _restoreSection() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_sectionKey);
      final section = _Section.values.where((v) => v.name == saved);
      if (section.isNotEmpty && mounted) {
        setState(() => _section = section.first);
      }
    } catch (_) {
      // The default section is fine.
    }
  }

  Future<void> _show(_Section section) async {
    setState(() => _section = section);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_sectionKey, section.name);
    } catch (_) {
      // Only the next visit's starting section is lost.
    }
  }

  /// A teacher starts on their circles; a student on their teachers, or on
  /// the directory while they have none.
  _Section _defaultSection(TahfeezProfile profile) => profile.isTeacher
      ? _Section.halaqat
      : (_myTeachers.isEmpty ? _Section.directory : _Section.teachers);

  /// The first time someone opens the tab without a country on their
  /// profile, ask for it: the directory starts from it.
  void _askCountryOnce(TahfeezProfile profile) {
    if (_askedCountry || profile.country != null || !mounted) return;
    _askedCountry = true;
    _pickCountry(profile, first: true);
  }

  @override
  void dispose() {
    AuthService.user.removeListener(_onAuthChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _onAuthChanged() {
    _profile = null;
    _halaqat = const [];
    _sessions = const [];
    _load();
  }

  Future<void> _load() async {
    if (AuthService.user.value == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final (profile, isNewProfile) = await TahfeezService.ensureProfile();
      final results = await Future.wait([
        TahfeezService.visibleHalaqat(),
        TahfeezService.visibleSessions(),
        profile.isTeacher
            ? Future.value(false)
            : TahfeezService.hasPendingRequest(),
        TahfeezService.enrollments(),
      ]);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _halaqat = results[0] as List<Halaqa>;
        _sessions = results[1] as List<TahfeezSession>;
        _pendingRequest = results[2] as bool;
        _enrollments = results[3] as List<Enrollment>;
        _loading = false;
      });
      if (isNewProfile && mounted) {
        await _welcomeNameDialog(profile);
      }
      if (mounted) _askCountryOnce(_profile ?? profile);
      _showNotices();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  String get _uid => AuthService.user.value!.id;

  /// Server-side notices meant for this user, each shown once — for now a
  /// student withdrawing a request that was still waiting on this teacher.
  Future<void> _showNotices() async {
    final notices = await TahfeezService.takeNotices();
    if (!mounted) return;
    for (final body in notices) {
      if (body == TahfeezService.teacherApprovedNotice ||
          body == TahfeezService.teacherRejectedNotice) {
        await _requestDecidedDialog(
          approved: body == TahfeezService.teacherApprovedNotice,
        );
        if (!mounted) return;
        continue;
      }
      final text = body.startsWith('cancelled_request:')
          ? t('tahfeez.notice.cancelledRequest').replaceAll(
              '{name}',
              body.substring('cancelled_request:'.length).trim().isEmpty
                  ? t('tahfeez.student')
                  : body.substring('cancelled_request:'.length).trim(),
            )
          : body;
      showNote(context, text);
    }
  }

  /// The answer to the reader's own teacher request — a dialog, not a
  /// snackbar, since it is news they were waiting for.
  Future<void> _requestDecidedDialog({required bool approved}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: tahfeezDirection(),
        child: AlertDialog(
          backgroundColor: AppColors.blackCard,
          icon: Icon(
            approved ? Icons.verified : Icons.info_outline,
            color: approved ? AppColors.gold : AppColors.textMuted,
            size: 36,
          ),
          title: Text(
            t(
              approved
                  ? 'tahfeez.notice.approvedTitle'
                  : 'tahfeez.notice.rejectedTitle',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.gold, fontSize: 17),
          ),
          content: Text(
            t(
              approved
                  ? 'tahfeez.notice.approvedBody'
                  : 'tahfeez.notice.rejectedBody',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(t('tahfeez.notice.ok')),
            ),
          ],
        ),
      ),
    );
  }

  List<Halaqa> get _taught =>
      _halaqat.where((h) => h.teacherId == _uid).toList();
  List<Halaqa> get _joined =>
      _halaqat.where((h) => h.teacherId != _uid).toList();

  /// Where the reader is the student.
  List<Enrollment> get _myTeachers =>
      _enrollments.where((e) => e.studentId == _uid).toList();

  /// Where the reader is the teacher.
  List<Enrollment> get _myStudents =>
      _enrollments.where((e) => e.teacherId == _uid).toList();

  Halaqa? _halaqaOf(String id) {
    for (final h in _halaqat) {
      if (h.id == id) return h;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // This tab is kept alive in an IndexedStack, so it must listen for the
    // app's general language changing — the only language it follows now —
    // or a language picked from the home screen never reaches a tab that
    // was already mounted.
    return ValueListenableBuilder<String>(
      valueListenable: AppLocale.locale,
      builder: (context, _, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    return Directionality(
      textDirection: tahfeezDirection(),
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('tahfeez.title')),
          centerTitle: true,
        ),
        body: ValueListenableBuilder<AppUser?>(
          valueListenable: AuthService.user,
          builder: (context, user, _) {
            if (user == null) return _signInView();
            if (_profile == null && _loading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              );
            }
            if (_profile == null) return _failedView();
            if (_profile!.blocked) return _blockedView();
            return _content(user, _profile!);
          },
        ),
      ),
    );
  }

  Widget _signInView() {
    return ValueListenableBuilder<Set<SignInProvider>>(
      valueListenable: AuthService.availableProviders,
      builder: (context, providers, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.school_rounded, size: 60, color: AppColors.gold),
              const SizedBox(height: 16),
              Text(
                t('tahfeez.signInPrompt'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 20),
              if (providers.isNotEmpty)
                for (final provider in SignInProvider.values.where(
                  providers.contains,
                ))
                  SignInButton(
                    provider: provider,
                    busy: _signingIn,
                    onPressed: _signingIn ? null : () => _signIn(provider),
                  )
              else
                Text(
                  t('tahfeez.signInComingSoon'),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signIn(SignInProvider provider) async {
    setState(() => _signingIn = true);
    final ok = await AuthService.signInWith(provider);
    if (!mounted) return;
    setState(() => _signingIn = false);
    if (!ok) showNote(context, t('tahfeez.signInFailed'), error: true);
  }

  Widget _blockedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.block, size: 56, color: AppColors.error),
            const SizedBox(height: 14),
            Text(
              t('tahfeez.youAreBlocked'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _failedView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            t('tahfeez.loadFailed'),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: _load,
            child: Text(
              t('tahfeez.retry'),
              style: const TextStyle(color: AppColors.gold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(AppUser user, TahfeezProfile profile) {
    final section = _section ?? _defaultSection(profile);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _profileCard(user, profile),
        ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              t('tahfeez.loadFailed'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: _sectionSwitch(section, profile),
        ),
        Expanded(
          child: section == _Section.directory
              ? _directory(profile)
              : RefreshIndicator(
                  color: AppColors.gold,
                  backgroundColor: AppColors.blackCard,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                    children: switch (section) {
                      _Section.halaqat => _halaqatSection(profile),
                      _Section.sessions => _sessionsSection(profile),
                      _Section.teachers => _teachersSection(profile),
                      _Section.directory => const [],
                    },
                  ),
                ),
        ),
      ],
    );
  }

  /// The four parts side by side as one switch, each an icon over its name.
  Widget _sectionSwitch(_Section current, TahfeezProfile profile) {
    final items = [
      (
        _Section.halaqat,
        Icons.menu_book_rounded,
        t('tahfeez.myHalaqat'),
        profile.isTeacher ? _myStudents.where((e) => e.isPending).length : 0,
      ),
      (_Section.sessions, Icons.schedule, t('tahfeez.tab.sessions'), 0),
      (_Section.teachers, Icons.school_outlined, t('tahfeez.myTeachers'), 0),
      (_Section.directory, Icons.person_search, t('tahfeez.directory'), 0),
    ];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.blackSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          for (final (section, icon, label, badge) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => _show(section),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  height: 56,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: section == current
                        ? AppColors.gold
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Badge(
                        isLabelVisible: badge > 0,
                        label: Text('$badge'),
                        backgroundColor: AppColors.error,
                        child: Icon(
                          icon,
                          size: 19,
                          color: section == current
                              ? AppColors.black
                              : AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: section == current
                              ? AppColors.black
                              : AppColors.textSecondary,
                          fontSize: 10.5,
                          fontWeight: section == current
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

  List<Widget> _halaqatSection(TahfeezProfile profile) => [
    if (profile.isTeacher) ...[
      SectionTitle(
        t('tahfeez.myHalaqat'),
        trailing: TextButton.icon(
          onPressed: _createHalaqa,
          icon: const Icon(Icons.add, size: 18, color: AppColors.gold),
          label: Text(
            t('tahfeez.newHalaqa'),
            style: const TextStyle(color: AppColors.gold, fontSize: 13),
          ),
        ),
      ),
      if (_taught.isEmpty)
        EmptyNote(icon: Icons.groups_outlined, text: t('tahfeez.noStudents'))
      else
        for (final h in _taught) ...[
          _halaqaCard(h, teacher: true),
          const SizedBox(height: 8),
        ],
      const SizedBox(height: 4),
      _tile(
        icon: Icons.groups,
        title: t('tahfeez.myStudents'),
        subtitle: _studentsSummary(),
        badge: _myStudents.where((e) => e.isPending).length,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  EnrollmentsScreen(sessions: _sessions, halaqat: _halaqat),
            ),
          );
          _load();
        },
      ),
      const SizedBox(height: 8),
      _tile(
        icon: Icons.badge_outlined,
        title: t('tahfeez.teacherProfile'),
        subtitle: t('tahfeez.teacherProfileSub'),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TeacherProfileScreen(profile: profile),
            ),
          );
          _load();
        },
      ),
    ],
    if (_joined.isNotEmpty) ...[
      const SizedBox(height: 14),
      SectionTitle(t('tahfeez.joinedHalaqat')),
      for (final h in _joined) ...[
        _halaqaCard(h, teacher: false),
        const SizedBox(height: 8),
      ],
      _tile(
        icon: Icons.timeline,
        title: t('tahfeez.myProgress'),
        subtitle: t('tahfeez.myProgressSub'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => StudentProgressScreen(
              studentId: _uid,
              title: t('tahfeez.myProgress'),
              sessions: _sessions,
              halaqat: _halaqat,
            ),
          ),
        ),
      ),
    ] else if (!profile.isTeacher)
      EmptyNote(icon: Icons.groups_outlined, text: t('tahfeez.noJoined')),
    const SizedBox(height: 12),
    _joinCard(),
  ];

  List<Widget> _sessionsSection(TahfeezProfile profile) {
    final today = weekdayOf(DateTime.now());
    final todays = _sessions.where((s) => s.weekday == today).toList()
      ..sort((a, b) => _mins(a.start).compareTo(_mins(b.start)));
    final rest = [
      for (final d in availabilityWeekOrder)
        if (d != today && _sessions.any((s) => s.weekday == d))
          (
            d,
            _sessions.where((s) => s.weekday == d).toList()
              ..sort((a, b) => _mins(a.start).compareTo(_mins(b.start))),
          ),
    ];
    return [
      SectionTitle('${t('tahfeez.sessionsOfDay')} — ${weekdayName(today)}'),
      if (todays.isEmpty)
        EmptyNote(icon: Icons.event_busy, text: t('tahfeez.noSessions'))
      else
        for (final s in todays) ...[_sessionCard(s), const SizedBox(height: 8)],
      if (rest.isNotEmpty) ...[
        const SizedBox(height: 10),
        SectionTitle(t('tahfeez.weekSessions')),
        for (final (day, list) in rest) ...[
          TahfeezCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    weekdayName(day),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final s in list)
                        Text(
                          '${_halaqaOf(s.halaqaId)?.name ?? ''}  ·  '
                          '${formatTime(s.start)} – ${formatTime(s.end)}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.7,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ],
      if (profile.isTeacher) ...[
        const SizedBox(height: 14),
        _tile(
          icon: Icons.calendar_month,
          title: t('tahfeez.schedule'),
          subtitle: t('tahfeez.scheduleSub'),
          onTap: _openSchedule,
        ),
        const SizedBox(height: 8),
        _tile(
          icon: Icons.event_available,
          title: t('tahfeez.avail.title'),
          subtitle: profile.availability.isEmpty
              ? t('tahfeez.avail.none')
              : availabilityByDay(
                  profile.availability,
                ).map((e) => weekdayName(e.$1)).join('، '),
          onTap: () => _openAvailability(profile),
        ),
      ],
    ];
  }

  static int _mins(TimeOfDay t) => t.hour * 60 + t.minute;

  List<Widget> _teachersSection(TahfeezProfile profile) => [
    if (_myTeachers.isEmpty) ...[
      EmptyNote(icon: Icons.school_outlined, text: t('tahfeez.noMyTeachers')),
      const SizedBox(height: 8),
      GoldButton(
        label: t('tahfeez.findTeacher'),
        icon: Icons.person_search,
        onPressed: () => _show(_Section.directory),
      ),
    ] else
      for (final e in _myTeachers) ...[
        _teacherEnrollmentCard(e),
        const SizedBox(height: 8),
      ],
    if (!profile.isTeacher) ...[
      const SizedBox(height: 16),
      _teacherRequestCard(),
    ],
  ];

  Widget _directory(TahfeezProfile profile) => TeachersDirectoryScreen(
    key: ValueKey('directory-${profile.country}'),
    embedded: true,
    enrollments: {for (final e in _myTeachers) e.teacherId: e},
    myGender: profile.gender,
    defaultCountry: profile.country,
    initialTeachers: widget.initialTeachers,
    header: profile.isTeacher ? _listedSwitch(profile) : null,
    onChanged: _load,
  );

  /// A teacher's own "show me in this list" switch, right where the list is.
  Widget _listedSwitch(TahfeezProfile profile) {
    return TahfeezCard(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          Icon(
            profile.listed ? Icons.visibility : Icons.visibility_off,
            color: AppColors.gold,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('tahfeez.listed'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                Text(
                  profile.listed
                      ? t('tahfeez.listedOn')
                      : t('tahfeez.listedOff'),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: profile.listed,
            activeThumbColor: AppColors.gold,
            onChanged: (v) => _setListed(v),
          ),
        ],
      ),
    );
  }

  Future<void> _setListed(bool listed) async {
    final before = _profile;
    setState(() => _profile = _profile?.copyWith(listed: listed));
    if (_offline) return;
    try {
      await TahfeezService.setListed(listed);
    } catch (e) {
      if (!mounted) return;
      setState(() => _profile = before);
      showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _openAvailability(TahfeezProfile profile) async {
    final saved = await Navigator.push<List<AvailabilitySlot>>(
      context,
      MaterialPageRoute(
        builder: (_) => AvailabilityScreen(
          initial: profile.availability,
          offline: _offline,
        ),
      ),
    );
    if (saved != null && mounted) {
      setState(() => _profile = _profile?.copyWith(availability: saved));
    }
  }

  Widget _tile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int badge = 0,
  }) {
    return TahfeezCard(
      onTap: onTap,
      child: Row(
        children: [
          Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            backgroundColor: AppColors.error,
            child: Icon(icon, color: AppColors.gold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
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

  String _studentsSummary() {
    final pending = _myStudents.where((e) => e.isPending).length;
    final soon = _myStudents.where((e) => e.endsSoon).length;
    final active = _myStudents.where((e) => e.isActive).length;
    final parts = <String>[
      if (pending > 0) '${t('tahfeez.newRequests')}: $pending',
      if (soon > 0) '${t('tahfeez.endingSoon')}: $soon',
      if (pending == 0 && soon == 0) '${t('tahfeez.activeStudents')}: $active',
    ];
    return parts.join(' · ');
  }

  Widget _teacherEnrollmentCard(Enrollment e) {
    final tp = e.teacher;
    final photo = tp?.photoUrl;
    return TahfeezCard(
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
                  tp?.displayName ?? '…',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                enrollmentStatusLine(e),
              ],
            ),
          ),
          if (e.status != EnrollmentStatus.rejected)
            IconButton(
              tooltip: t('tahfeez.chat'),
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.gold,
                size: 20,
              ),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => ChatScreen(enrollment: e)),
              ),
            ),
          if (e.status != EnrollmentStatus.rejected)
            IconButton(
              tooltip: e.isPending
                  ? t('tahfeez.cancelRequest')
                  : t('tahfeez.leaveTeacher'),
              icon: const Icon(
                Icons.close,
                color: AppColors.textMuted,
                size: 18,
              ),
              onPressed: () => _leaveTeacher(e),
            ),
        ],
      ),
    );
  }

  Future<void> _leaveTeacher(Enrollment e) async {
    final ok = await confirmDialog(
      context,
      message: e.isPending
          ? t('tahfeez.cancelRequest')
          : t('tahfeez.leaveTeacherConfirm'),
      confirmLabel: e.isPending
          ? t('tahfeez.cancelRequest')
          : t('tahfeez.leaveTeacher'),
    );
    if (!ok || !mounted) return;
    try {
      await TahfeezService.cancelEnrollment(e.id);
      await _load();
    } catch (err) {
      if (mounted) showNote(context, describeError(err), error: true);
    }
  }

  /// Gender as one compact chip — the same "icon plus current value, tap to
  /// pick from a list" shape as the country chip beside it, instead of two
  /// always-visible toggle chips.
  Widget _genderChip(TahfeezProfile profile) {
    final set = profile.gender != null;
    return GestureDetector(
      onTap: () => _pickGender(profile),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 96),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: set ? AppColors.goldMuted : Colors.transparent,
          border: Border.all(
            color: set ? AppColors.gold : AppColors.goldBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_outline,
              size: 12,
              color: set ? AppColors.gold : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                set
                    ? t('tahfeez.gender.${profile.gender!.name}')
                    : t('tahfeez.genderHint'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: set ? AppColors.gold : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickGender(TahfeezProfile profile) async {
    final chosen = await showModalBottomSheet<Gender>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    t('tahfeez.genderHint'),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              for (final g in Gender.values)
                ListTile(
                  title: Text(
                    t('tahfeez.gender.${g.name}'),
                    style: TextStyle(
                      color: g == profile.gender
                          ? AppColors.gold
                          : AppColors.textPrimary,
                      fontWeight: g == profile.gender
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: g == profile.gender
                      ? const Icon(Icons.check, color: AppColors.gold)
                      : null,
                  onTap: () => Navigator.pop(ctx, g),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || chosen == profile.gender || !mounted) return;
    try {
      await TahfeezService.setGender(chosen);
      if (mounted) {
        setState(() => _profile = _profile?.copyWith(gender: chosen));
      }
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  /// Country as a small chip beside gender, tapped to open the same picker —
  /// no longer its own full-width row now that gender sits right next to it.
  Widget _countryChip(TahfeezProfile profile) {
    final set = profile.country != null;
    return GestureDetector(
      onTap: () => _pickCountry(profile),
      behavior: HitTestBehavior.opaque,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 96),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: set ? AppColors.goldMuted : Colors.transparent,
          border: Border.all(
            color: set ? AppColors.gold : AppColors.goldBorder,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.public,
              size: 12,
              color: set ? AppColors.gold : AppColors.textMuted,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                set ? countryName(profile.country!) : t('tahfeez.countryHint'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: set ? AppColors.gold : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCountry(
    TahfeezProfile profile, {
    bool first = false,
  }) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isDismissible: !first,
      enableDrag: !first,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.85,
          builder: (ctx, scrollController) => ListView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(vertical: 12),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  first ? t('tahfeez.pickCountryTitle') : t('tahfeez.country'),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (first)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Text(
                    t('tahfeez.pickCountrySub'),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              for (final (code, _, _) in tahfeezCountries)
                ListTile(
                  title: Text(
                    countryName(code),
                    style: TextStyle(
                      color: code == profile.country
                          ? AppColors.gold
                          : AppColors.textPrimary,
                      fontWeight: code == profile.country
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  trailing: code == profile.country
                      ? const Icon(Icons.check, color: AppColors.gold)
                      : null,
                  onTap: () => Navigator.pop(ctx, code),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null || chosen == profile.country || !mounted) return;
    if (_offline) {
      setState(() => _profile = _profile?.copyWith(country: chosen));
      return;
    }
    try {
      await TahfeezService.setCountry(chosen);
      if (mounted) {
        setState(() => _profile = _profile?.copyWith(country: chosen));
      }
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  /// The reader's identity, in one card: avatar, name, role, gender,
  /// country, and — for a teacher — their invite code. Three cards used to
  /// say this; one says it in less space.
  Widget _profileCard(AppUser user, TahfeezProfile profile) {
    final code = profile.isTeacher ? profile.teacherCode : null;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              UserAvatar(user: user, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            profile.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.gold,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => _editName(profile),
                          child: const Icon(
                            Icons.edit,
                            size: 15,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: profile.isTeacher
                            ? AppColors.goldMuted
                            : AppColors.emeraldMuted,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        profile.isTeacher
                            ? t('tahfeez.teacher')
                            : t('tahfeez.student'),
                        style: TextStyle(
                          color: profile.isTeacher
                              ? AppColors.gold
                              : AppColors.emeraldLight,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _genderChip(profile),
                      const SizedBox(width: 6),
                      _countryChip(profile),
                    ],
                  ),
                  if (code != null) ...[
                    const SizedBox(height: 6),
                    _teacherCodeCompact(code),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// The invite code, shrunk to fit the trailing column beside the header
  /// instead of its own full-width row — the card's whole reason for being
  /// one card and not three was to take less space, and gender/country
  /// moving onto a single line freed exactly enough room for this.
  Widget _teacherCodeCompact(String code) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          code,
          textDirection: TextDirection.ltr,
          style: const TextStyle(
            color: AppColors.gold,
            fontSize: 13,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: code));
            if (mounted) showNote(context, t('tahfeez.codeCopied'));
          },
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(3),
            child: Icon(Icons.copy, color: AppColors.gold, size: 14),
          ),
        ),
        GestureDetector(
          onTap: () => SharePlus.instance.share(
            ShareParams(
              text: t('tahfeez.shareTeacherCode').replaceAll('{code}', code),
            ),
          ),
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.all(3),
            child: Icon(Icons.share, color: AppColors.gold, size: 14),
          ),
        ),
      ],
    );
  }

  /// Shown once, right when the reader's Tahfeez profile is first created —
  /// their chance to pick what a teacher or student sees before it defaults
  /// silently to their Google name.
  Future<void> _welcomeNameDialog(TahfeezProfile profile) async {
    final name = await promptText(
      context,
      title: t('tahfeez.welcomeNameTitle'),
      subtitle: t('tahfeez.editNameNote'),
      hint: t('tahfeez.editNameHint'),
      initial: profile.displayName,
      confirmLabel: t('tahfeez.save'),
    );
    if (name == null || name.isEmpty || name == profile.displayName) return;
    if (!mounted) return;
    try {
      await TahfeezService.setDisplayName(name);
      if (mounted) {
        setState(() => _profile = _profile?.copyWith(displayName: name));
      }
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _editName(TahfeezProfile profile) async {
    final name = await promptText(
      context,
      title: t('tahfeez.editName'),
      hint: t('tahfeez.editNameHint'),
      initial: profile.displayName,
      confirmLabel: t('tahfeez.save'),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await TahfeezService.setDisplayName(name);
      if (!mounted) return;
      showNote(context, t('tahfeez.nameUpdated'));
      await _load();
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Widget _halaqaCard(Halaqa h, {required bool teacher}) {
    final count = _sessions.where((s) => s.halaqaId == h.id).length;
    return TahfeezCard(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => teacher
                ? HalaqaScreen(halaqa: h)
                : StudentHalaqaScreen(
                    halaqa: h,
                    sessions: _sessions
                        .where((s) => s.halaqaId == h.id)
                        .toList(),
                  ),
          ),
        );
        _load();
      },
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
                Text(
                  h.name,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$count ${t('tahfeez.sessionsOfDay')}',
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

  Widget _sessionCard(TahfeezSession s) {
    final h = _halaqaOf(s.halaqaId);
    final mine = h != null && h.teacherId == _uid;
    return TahfeezCard(
      onTap: h == null
          ? null
          : () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => mine
                    ? SessionEvaluationScreen(
                        session: s,
                        halaqa: h,
                        date: DateTime.now(),
                      )
                    : StudentHalaqaScreen(
                        halaqa: h,
                        sessions: _sessions
                            .where((x) => x.halaqaId == h.id)
                            .toList(),
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
                  h?.name ?? '',
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${formatTime(s.start)} – ${formatTime(s.end)}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (mine)
            Text(
              t('tahfeez.evaluate'),
              style: const TextStyle(color: AppColors.gold, fontSize: 12),
            ),
          Icon(tahfeezChevron, color: AppColors.textMuted),
        ],
      ),
    );
  }

  Widget _joinCard() {
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('tahfeez.joinTitle'),
            style: const TextStyle(
              color: AppColors.textGold,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            t('tahfeez.joinSub'),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
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
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.gold),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _joining ? null : _join,
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
                child: _joining
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.black,
                        ),
                      )
                    : Text(
                        t('tahfeez.joinButton'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _join() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) return;
    setState(() => _joining = true);
    try {
      final name = await TahfeezService.requestEnrollmentByCode(code, '');
      if (!mounted) return;
      _codeController.clear();
      FocusScope.of(context).unfocus();
      showNote(context, '${t('tahfeez.joined')}: $name');
      await _load();
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Widget _teacherRequestCard() {
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: AppColors.gold),
              const SizedBox(width: 10),
              Text(
                t('tahfeez.requestTeacherTitle'),
                style: const TextStyle(
                  color: AppColors.textGold,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _pendingRequest
                ? t('tahfeez.requestPending')
                : t('tahfeez.requestTeacherSub'),
            style: TextStyle(
              color: _pendingRequest
                  ? AppColors.goldLight
                  : AppColors.textMuted,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          if (!_pendingRequest) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _requestTeacher,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.gold,
                side: const BorderSide(color: AppColors.goldBorder),
              ),
              child: Text(t('tahfeez.requestTeacherButton')),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _requestTeacher() async {
    final note = await promptText(
      context,
      title: t('tahfeez.requestTeacherTitle'),
      hint: t('tahfeez.requestNoteHint'),
      confirmLabel: t('tahfeez.requestTeacherButton'),
      maxLines: 3,
    );
    if (note == null || !mounted) return;
    try {
      await TahfeezService.requestTeacherRole(note);
      if (!mounted) return;
      showNote(context, t('tahfeez.requestSent'));
      setState(() => _pendingRequest = true);
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _createHalaqa() async {
    final name = await promptText(
      context,
      title: t('tahfeez.newHalaqa'),
      hint: t('tahfeez.halaqaNameHint'),
      confirmLabel: t('tahfeez.create'),
    );
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await TahfeezService.createHalaqa(name);
      await _load();
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _openSchedule() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleScreen(
          halaqat: _taught,
          sessions: _sessions,
          enrollments: _myStudents,
        ),
      ),
    );
    _load();
  }
}
