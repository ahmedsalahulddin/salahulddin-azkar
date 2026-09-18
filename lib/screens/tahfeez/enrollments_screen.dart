import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/auth_service.dart';
import '../../services/tahfeez_service.dart';
import 'chat_screen.dart';
import 'student_progress_screen.dart';
import 'tahfeez_widgets.dart';

/// A teacher's students: who is asking, who is subscribed, whose term has
/// run out — and the answers to each.
class EnrollmentsScreen extends StatefulWidget {
  final List<TahfeezSession> sessions;
  final List<Halaqa> halaqat;

  const EnrollmentsScreen({
    super.key,
    required this.sessions,
    required this.halaqat,
  });

  @override
  State<EnrollmentsScreen> createState() => _EnrollmentsScreenState();
}

class _EnrollmentsScreenState extends State<EnrollmentsScreen> {
  List<Enrollment> _all = const [];
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await TahfeezService.enrollments();
      if (!mounted) return;
      setState(() {
        final me = AuthService.user.value!.id;
        _all = list.where((e) => e.teacherId == me).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNote(context, describeError(e), error: true);
    }
  }

  List<Enrollment> get _pending => _all.where((e) => e.isPending).toList();
  List<Enrollment> get _active => _all.where((e) => e.isActive).toList();
  List<Enrollment> get _expired => _all.where((e) => e.isExpired).toList();

  Future<void> _run(Enrollment e, Future<void> Function() action) async {
    setState(() => _busyId = e.id);
    try {
      await action();
      await _load();
    } catch (err) {
      if (mounted) showNote(context, describeError(err), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
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
          title: Text(t('tahfeez.myStudents')),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _all.isEmpty
            ? EmptyNote(
                icon: Icons.groups_outlined,
                text: t('tahfeez.noEnrollments'),
              )
            : RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.blackCard,
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_pending.isNotEmpty) ...[
                      SectionTitle(
                        '${t('tahfeez.pendingRequests')} (${_pending.length})',
                      ),
                      for (final e in _pending) ...[
                        _card(e),
                        const SizedBox(height: 8),
                      ],
                      const SizedBox(height: 12),
                    ],
                    SectionTitle(
                      '${t('tahfeez.activeStudents')} (${_active.length})',
                    ),
                    if (_active.isEmpty)
                      EmptyNote(
                        icon: Icons.person_outline,
                        text: t('tahfeez.noEnrollments'),
                      )
                    else
                      for (final e in _active) ...[
                        _card(e),
                        const SizedBox(height: 8),
                      ],
                    if (_expired.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SectionTitle(
                        '${t('tahfeez.expiredStudents')} (${_expired.length})',
                      ),
                      for (final e in _expired) ...[
                        _card(e),
                        const SizedBox(height: 8),
                      ],
                    ],
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _card(Enrollment e) {
    final s = e.student;
    final photo = s?.photoUrl;
    final busy = _busyId == e.id;
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: e.isPending
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentProgressScreen(
                        studentId: e.studentId,
                        title: s?.displayName ?? '',
                        sessions: widget.sessions,
                        halaqat: widget.halaqat,
                      ),
                    ),
                  ),
            behavior: HitTestBehavior.opaque,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.goldMuted,
                  backgroundImage: photo != null ? NetworkImage(photo) : null,
                  child: photo == null
                      ? const Icon(
                          Icons.person,
                          color: AppColors.gold,
                          size: 20,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s?.displayName ?? '…',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      enrollmentStatusLine(e),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: t('tahfeez.chat'),
                  icon: const Icon(
                    Icons.chat_bubble_outline,
                    color: AppColors.gold,
                    size: 20,
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(enrollment: e),
                    ),
                  ),
                ),
                if (!e.isPending)
                  Icon(tahfeezChevron, color: AppColors.textMuted),
              ],
            ),
          ),
          if (e.isPending && e.note != null && e.note!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.blackSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                e.note!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (e.isPending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _run(
                            e,
                            () => TahfeezService.decideEnrollment(
                              e.id,
                              approve: true,
                            ),
                          ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: AppColors.textPrimary,
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: Text(t('tahfeez.approve')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _run(
                            e,
                            () => TahfeezService.decideEnrollment(
                              e.id,
                              approve: false,
                            ),
                          ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: Text(t('tahfeez.reject')),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _run(
                          e,
                          () => TahfeezService.setEnrollmentPaid(e.id, !e.paid),
                        ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: e.paid
                        ? AppColors.textMuted
                        : AppColors.success,
                    side: BorderSide(
                      color: e.paid ? AppColors.goldBorder : AppColors.success,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(
                    e.paid ? Icons.money_off : Icons.payments_outlined,
                    size: 15,
                  ),
                  label: Text(
                    e.paid ? t('tahfeez.markUnpaid') : t('tahfeez.markPaid'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () =>
                            _run(e, () => TahfeezService.renewEnrollment(e.id)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.gold,
                    side: const BorderSide(color: AppColors.goldBorder),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.autorenew, size: 15),
                  label: Text(
                    t('tahfeez.renew'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                TextButton.icon(
                  onPressed: busy ? null : () => _end(e),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.error,
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.person_remove_outlined, size: 15),
                  label: Text(
                    t('tahfeez.endEnrollment'),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _end(Enrollment e) async {
    final ok = await confirmDialog(
      context,
      message: t('tahfeez.endEnrollmentConfirm'),
      confirmLabel: t('tahfeez.endEnrollment'),
    );
    if (!ok || !mounted) return;
    await _run(e, () => TahfeezService.cancelEnrollment(e.id));
  }
}

/// "مشترك · ينتهي بعد 5 يوم · مدفوع · 2 حصص مجانية متبقية", in the colour
/// of its state. Shared by both sides of the enrolment.
Widget enrollmentStatusLine(Enrollment e) {
  final parts = <String>[];
  final Color color;
  if (e.isPending) {
    parts.add(t('tahfeez.status.pending'));
    color = AppColors.goldLight;
  } else if (e.status == EnrollmentStatus.rejected) {
    parts.add(t('tahfeez.status.rejected'));
    color = AppColors.textMuted;
  } else if (e.isExpired) {
    parts.add(t('tahfeez.status.expired'));
    parts.add('${t('tahfeez.endedSince')} ${-e.daysLeft} ${t('tahfeez.days')}');
    color = AppColors.error;
  } else {
    parts.add(t('tahfeez.status.active'));
    parts.add(
      e.daysLeft == 0
          ? t('tahfeez.endsToday')
          : '${t('tahfeez.endsIn')} ${e.daysLeft} ${t('tahfeez.days')}',
    );
    parts.add(e.paid ? t('tahfeez.paid') : t('tahfeez.unpaid'));
    if (e.freeSessionsLeft > 0) {
      parts.add('${e.freeSessionsLeft} ${t('tahfeez.freeLeft')}');
    }
    color = e.endsSoon ? AppColors.goldLight : AppColors.success;
  }
  return Text(
    parts.join(' · '),
    style: TextStyle(color: color, fontSize: 12, height: 1.5),
  );
}
