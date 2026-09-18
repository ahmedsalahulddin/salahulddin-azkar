import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
import 'tahfeez_widgets.dart';

/// Admin only: who has asked to be a teacher, and the two answers.
class TeacherRequestsScreen extends StatefulWidget {
  const TeacherRequestsScreen({super.key});

  @override
  State<TeacherRequestsScreen> createState() => _TeacherRequestsScreenState();
}

class _TeacherRequestsScreenState extends State<TeacherRequestsScreen> {
  List<TeacherRequest> _requests = const [];
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await TahfeezService.pendingRequests();
      if (!mounted) return;
      setState(() {
        _requests = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _decide(TeacherRequest r, bool approve) async {
    setState(() => _busyId = r.id);
    try {
      await TahfeezService.decideRequest(r.id, approve: approve);
      if (!mounted) return;
      setState(() => _requests = _requests.where((x) => x.id != r.id).toList());
      TahfeezService.refreshPendingBadge();
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
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
          title: Text(t('account.teacherRequestsTitle')),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _requests.isEmpty
            ? EmptyNote(
                icon: Icons.inbox_outlined,
                text: t('tahfeez.noRequests'),
              )
            : RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.blackCard,
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _card(_requests[i]),
                ),
              ),
      ),
    );
  }

  Widget _card(TeacherRequest r) {
    final photo = r.profile?.photoUrl;
    final busy = _busyId == r.id;
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
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
                      r.profile?.displayName ?? r.userId,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${t('tahfeez.requestedAt')} ${formatDate(r.createdAt.toLocal())}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (r.note != null && r.note!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.blackSurface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                r.note!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.6,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: busy ? null : () => _decide(r, true),
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
                  onPressed: busy ? null : () => _decide(r, false),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(t('tahfeez.reject')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
