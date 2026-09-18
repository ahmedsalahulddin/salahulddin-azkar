import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
import 'session_evaluation_screen.dart';
import 'student_progress_screen.dart';
import 'tahfeez_widgets.dart';

/// A teacher's view of one circle: the code that lets students in, who has
/// joined, and the slots it occupies in the week.
class HalaqaScreen extends StatefulWidget {
  final Halaqa halaqa;

  const HalaqaScreen({super.key, required this.halaqa});

  @override
  State<HalaqaScreen> createState() => _HalaqaScreenState();
}

class _HalaqaScreenState extends State<HalaqaScreen> {
  late Halaqa _halaqa = widget.halaqa;
  List<HalaqaMember> _members = const [];
  List<TahfeezSession> _sessions = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        TahfeezService.members(_halaqa.id),
        TahfeezService.visibleSessions(),
      ]);
      if (!mounted) return;
      setState(() {
        _members = results[0] as List<HalaqaMember>;
        _sessions = (results[1] as List<TahfeezSession>)
            .where((s) => s.halaqaId == _halaqa.id)
            .toList();
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
      textDirection: TextDirection.rtl,
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
            : RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.blackCard,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _codeCard(),
                    const SizedBox(height: 18),
                    SectionTitle(
                      '${t('tahfeez.students')} (${_members.length})',
                    ),
                    if (_members.isEmpty)
                      EmptyNote(
                        icon: Icons.groups_outlined,
                        text: t('tahfeez.noStudents'),
                      )
                    else
                      for (final m in _members) ...[
                        _memberCard(m),
                        const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 18),
                    SectionTitle(t('tahfeez.schedule')),
                    if (_sessions.isEmpty)
                      EmptyNote(
                        icon: Icons.event_busy,
                        text: t('tahfeez.noSessions'),
                      )
                    else
                      for (final s in _sessions) ...[
                        _sessionCard(s),
                        const SizedBox(height: 8),
                      ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
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
          const Icon(Icons.chevron_left, color: AppColors.textMuted),
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
        textDirection: TextDirection.rtl,
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

  Widget _memberCard(HalaqaMember m) {
    final photo = m.profile?.photoUrl;
    return TahfeezCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => StudentProgressScreen(
            studentId: m.studentId,
            title: m.name,
            sessions: _sessions,
            halaqat: [_halaqa],
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            child: Text(
              m.name,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
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
            child: Text(
              '${weekdayName(s.weekday)} · ${formatTime(s.start)} – ${formatTime(s.end)}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
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
