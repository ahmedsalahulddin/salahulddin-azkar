import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/auth_service.dart';
import '../../services/tahfeez_service.dart';
import '../../widgets/sign_in_buttons.dart';
import '../account_screen.dart' show UserAvatar;
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
  const TahfeezTab({super.key});

  @override
  State<TahfeezTab> createState() => _TahfeezTabState();
}

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

  @override
  void initState() {
    super.initState();
    AuthService.user.addListener(_onAuthChanged);
    _load();
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
      if (isNewProfile && mounted) _welcomeNameDialog(profile);
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
    return Directionality(
      textDirection: TextDirection.rtl,
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
            return RefreshIndicator(
              color: AppColors.gold,
              backgroundColor: AppColors.blackCard,
              onRefresh: _load,
              child: _content(user, _profile!),
            );
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
              if (providers.contains(SignInProvider.google))
                SignInButton(
                  provider: SignInProvider.google,
                  busy: _signingIn,
                  onPressed: _signingIn ? null : _signIn,
                )
              else
                Text(
                  t('account.signInSoon'),
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

  Future<void> _signIn() async {
    setState(() => _signingIn = true);
    final ok = await AuthService.signInWith(SignInProvider.google);
    if (!mounted) return;
    setState(() => _signingIn = false);
    if (!ok) showNote(context, t('account.signInFail'), error: true);
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
    final today = weekdayOf(DateTime.now());
    final taughtIds = _taught.map((h) => h.id).toSet();
    final todaySessions = _sessions
        .where((s) => s.weekday == today && taughtIds.contains(s.halaqaId))
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _header(user, profile),
        if (profile.isTeacher && profile.teacherCode != null) ...[
          const SizedBox(height: 10),
          _teacherCodeCard(profile),
        ],
        const SizedBox(height: 10),
        _genderCard(profile),
        if (_failed) ...[
          const SizedBox(height: 10),
          Text(
            t('tahfeez.loadFailed'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.error, fontSize: 12),
          ),
        ],
        if (profile.isTeacher) ...[
          const SizedBox(height: 18),
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
            EmptyNote(
              icon: Icons.groups_outlined,
              text: t('tahfeez.noStudents'),
            )
          else
            for (final h in _taught) ...[
              _halaqaCard(h, teacher: true),
              const SizedBox(height: 8),
            ],
          const SizedBox(height: 10),
          TahfeezCard(
            onTap: _openSchedule,
            child: Row(
              children: [
                const Icon(Icons.calendar_month, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('tahfeez.schedule'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_left, color: AppColors.textMuted),
              ],
            ),
          ),
          const SizedBox(height: 8),
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
          const SizedBox(height: 18),
          SectionTitle('${t('tahfeez.sessionsOfDay')} — ${weekdayName(today)}'),
          if (todaySessions.isEmpty)
            EmptyNote(icon: Icons.event_busy, text: t('tahfeez.noSessions'))
          else
            for (final s in todaySessions) ...[
              _sessionCard(s),
              const SizedBox(height: 8),
            ],
        ],
        if (_joined.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionTitle(t('tahfeez.joinedHalaqat')),
          for (final h in _joined) ...[
            _halaqaCard(h, teacher: false),
            const SizedBox(height: 8),
          ],
          TahfeezCard(
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
            child: Row(
              children: [
                const Icon(Icons.timeline, color: AppColors.gold),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    t('tahfeez.myProgress'),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_left, color: AppColors.textMuted),
              ],
            ),
          ),
        ],
        if (_myTeachers.isNotEmpty) ...[
          const SizedBox(height: 18),
          SectionTitle(t('tahfeez.myTeachers')),
          for (final e in _myTeachers) ...[
            _teacherEnrollmentCard(e),
            const SizedBox(height: 8),
          ],
        ],
        const SizedBox(height: 18),
        _tile(
          icon: Icons.person_search,
          title: t('tahfeez.directory'),
          subtitle: t('tahfeez.directorySub'),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TeachersDirectoryScreen(
                  enrollments: {for (final e in _myTeachers) e.teacherId: e},
                  myGender: profile.gender,
                ),
              ),
            );
            _load();
          },
        ),
        const SizedBox(height: 12),
        _joinCard(),
        if (!profile.isTeacher) ...[
          const SizedBox(height: 12),
          _teacherRequestCard(),
        ],
        const SizedBox(height: 30),
      ],
    );
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
          const Icon(Icons.chevron_left, color: AppColors.textMuted),
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

  Widget _teacherCodeCard(TahfeezProfile profile) {
    final code = profile.teacherCode!;
    return TahfeezCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('tahfeez.teacherCode'),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                Text(
                  code,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 22,
                    letterSpacing: 5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t('tahfeez.codeCopied'),
            icon: const Icon(Icons.copy, color: AppColors.gold, size: 20),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: code));
              if (mounted) showNote(context, t('tahfeez.codeCopied'));
            },
          ),
          IconButton(
            tooltip: t('tahfeez.shareCode'),
            icon: const Icon(Icons.share, color: AppColors.gold, size: 20),
            onPressed: () => SharePlus.instance.share(
              ShareParams(
                text: t('tahfeez.shareTeacherCode').replaceAll('{code}', code),
              ),
            ),
          ),
        ],
      ),
    );
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

  Widget _genderCard(TahfeezProfile profile) {
    return TahfeezCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('tahfeez.myGender'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13,
                  ),
                ),
                if (profile.gender == null)
                  Text(
                    t('tahfeez.myGenderSub'),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          for (final g in Gender.values) ...[
            ChoiceChip(
              label: Text(t('tahfeez.gender.${g.name}')),
              selected: profile.gender == g,
              selectedColor: AppColors.goldMuted,
              backgroundColor: AppColors.blackSurface,
              side: BorderSide(
                color: profile.gender == g
                    ? AppColors.gold
                    : AppColors.goldBorder,
              ),
              labelStyle: TextStyle(
                color: profile.gender == g
                    ? AppColors.gold
                    : AppColors.textMuted,
                fontSize: 12,
              ),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
              onSelected: (_) => _setGender(g),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }

  Future<void> _setGender(Gender g) async {
    try {
      await TahfeezService.setGender(g);
      if (mounted) {
        setState(() => _profile = _profile?.copyWith(gender: g));
      }
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  Widget _header(AppUser user, TahfeezProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.navyLight, AppColors.navy],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          UserAvatar(user: user, size: 52),
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
        ],
      ),
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
          const Icon(Icons.chevron_left, color: AppColors.textMuted),
        ],
      ),
    );
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
          Text(
            t('tahfeez.evaluate'),
            style: const TextStyle(color: AppColors.gold, fontSize: 12),
          ),
          const Icon(Icons.chevron_left, color: AppColors.textMuted),
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
        builder: (_) => ScheduleScreen(halaqat: _taught, sessions: _sessions),
      ),
    );
    _load();
  }
}
