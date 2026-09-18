import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/tahfeez_service.dart';
import 'tahfeez_widgets.dart';

/// Admin only: every reported message, with the sender and the two
/// answers — block them (account and device) or let it go.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<TahfeezMessage> _reports = const [];
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await TahfeezService.reportedMessages();
      if (!mounted) return;
      setState(() {
        _reports = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNote(context, describeError(e), error: true);
    }
  }

  Future<void> _run(TahfeezMessage m, Future<void> Function() action) async {
    setState(() => _busyId = m.id);
    try {
      await action();
      await _load();
      TahfeezService.refreshPendingBadge();
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _block(TahfeezMessage m) async {
    final ok = await confirmDialog(
      context,
      message: t('tahfeez.blockConfirm'),
      confirmLabel: t('tahfeez.blockUser'),
    );
    if (!ok || !mounted) return;
    final reason = await promptText(
      context,
      title: t('tahfeez.blockUser'),
      hint: t('tahfeez.blockReasonHint'),
      confirmLabel: t('tahfeez.blockUser'),
    );
    if (reason == null || !mounted) return;
    await _run(m, () async {
      await TahfeezService.blockUser(m.senderId, reason);
      await TahfeezService.dismissReport(m.id);
    });
    if (mounted) showNote(context, t('tahfeez.blocked'));
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
          title: Text(t('tahfeez.reports')),
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _reports.isEmpty
            ? EmptyNote(icon: Icons.flag_outlined, text: t('tahfeez.noReports'))
            : RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.blackCard,
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _reports.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _card(_reports[i]),
                ),
              ),
      ),
    );
  }

  Widget _card(TahfeezMessage m) {
    final sender = m.sender;
    final photo = sender?.photoUrl;
    final busy = _busyId == m.id;
    return TahfeezCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                      sender?.displayName ?? m.senderId,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${t('tahfeez.reportedBy')} · '
                      '${m.reportedAt == null ? '' : formatDate(m.reportedAt!)}',
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (sender?.blocked == true)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    t('tahfeez.blocked'),
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.blackSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Text(
              m.body,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),
          if (m.reportReason != null && m.reportReason!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${t('tahfeez.reason')}: ${m.reportReason}',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: sender?.blocked == true
                    ? OutlinedButton.icon(
                        onPressed: busy
                            ? null
                            : () => _run(
                                m,
                                () => TahfeezService.unblockUser(m.senderId),
                              ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.gold,
                          side: const BorderSide(color: AppColors.goldBorder),
                        ),
                        icon: const Icon(Icons.lock_open, size: 16),
                        label: Text(t('tahfeez.unblock')),
                      )
                    : ElevatedButton.icon(
                        onPressed: busy ? null : () => _block(m),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.textPrimary,
                        ),
                        icon: const Icon(Icons.block, size: 16),
                        label: Text(t('tahfeez.blockUser')),
                      ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy
                      ? null
                      : () => _run(m, () => TahfeezService.dismissReport(m.id)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textMuted,
                    side: const BorderSide(color: AppColors.goldBorder),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: Text(t('tahfeez.dismissReport')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
