import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/auth_service.dart';
import '../../services/tahfeez_service.dart';
import 'student_progress_screen.dart';
import 'tahfeez_widgets.dart';

/// A student's view of a circle they belong to: who teaches it, when it
/// meets, and the way out.
class StudentHalaqaScreen extends StatefulWidget {
  final Halaqa halaqa;
  final List<TahfeezSession> sessions;

  const StudentHalaqaScreen({
    super.key,
    required this.halaqa,
    required this.sessions,
  });

  @override
  State<StudentHalaqaScreen> createState() => _StudentHalaqaScreenState();
}

class _StudentHalaqaScreenState extends State<StudentHalaqaScreen> {
  TahfeezProfile? _teacher;

  @override
  void initState() {
    super.initState();
    TahfeezService.profileOf(widget.halaqa.teacherId)
        .then((p) {
          if (mounted) setState(() => _teacher = p);
        })
        .catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final sessions = List.of(widget.sessions)
      ..sort(
        (a, b) => a.weekday != b.weekday
            ? a.weekday.compareTo(b.weekday)
            : (a.start.hour * 60 + a.start.minute).compareTo(
                b.start.hour * 60 + b.start.minute,
              ),
      );
    final photo = _teacher?.photoUrl;

    return Directionality(
      textDirection: tahfeezDirection(),
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(widget.halaqa.name),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TahfeezCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: AppColors.goldMuted,
                    backgroundImage: photo != null ? NetworkImage(photo) : null,
                    child: photo == null
                        ? const Icon(Icons.person, color: AppColors.gold)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t('tahfeez.teacher'),
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _teacher?.displayName ?? '…',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionTitle(t('tahfeez.schedule')),
            if (sessions.isEmpty)
              EmptyNote(icon: Icons.event_busy, text: t('tahfeez.noSessions'))
            else
              for (final s in sessions) ...[
                TahfeezCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.schedule,
                        color: AppColors.gold,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${weekdayName(s.weekday)} · ${formatTime(s.start)} – ${formatTime(s.end)}',
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            const SizedBox(height: 12),
            GoldButton(
              label: t('tahfeez.myProgress'),
              icon: Icons.timeline,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentProgressScreen(
                    studentId: AuthService.user.value!.id,
                    title: t('tahfeez.myProgress'),
                    sessions: widget.sessions,
                    halaqat: [widget.halaqa],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _leave,
              icon: const Icon(Icons.logout, size: 16),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              label: Text(t('tahfeez.leaveHalaqa')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leave() async {
    final ok = await confirmDialog(
      context,
      message: t('tahfeez.leaveHalaqaConfirm'),
      confirmLabel: t('tahfeez.leaveHalaqa'),
    );
    if (!ok || !mounted) return;
    try {
      await TahfeezService.removeMember(
        widget.halaqa.id,
        AuthService.user.value!.id,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }
}
