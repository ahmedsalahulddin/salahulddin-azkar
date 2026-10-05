import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/account_lang.dart';
import '../../services/support_service.dart';
import 'support_thread_screen.dart';
import 'support_widgets.dart';

enum _Filter { open, resolved, starred, all }

/// Every request readers sent, for the admins: open ones first by default,
/// a star on any to come back to, and each one marked solved when it is.
class AdminInboxScreen extends StatefulWidget {
  @visibleForTesting
  final List<SupportThread>? initialThreads;
  @visibleForTesting
  final Map<String, List<SupportMessage>>? initialMessages;

  const AdminInboxScreen({
    super.key,
    this.initialThreads,
    this.initialMessages,
  });

  @override
  State<AdminInboxScreen> createState() => _AdminInboxScreenState();
}

class _AdminInboxScreenState extends State<AdminInboxScreen> {
  List<SupportThread>? _threads;
  bool _failed = false;
  _Filter _filter = _Filter.open;

  bool get _offline => widget.initialThreads != null;

  @override
  void initState() {
    super.initState();
    if (_offline) {
      _threads = widget.initialThreads;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    final list = await SupportService.allThreads();
    if (!mounted) return;
    setState(() {
      _threads = list ?? _threads;
      _failed = list == null;
    });
  }

  List<SupportThread> _shown(List<SupportThread> all) => switch (_filter) {
    _Filter.open => all.where((t) => !t.resolved).toList(),
    _Filter.resolved => all.where((t) => t.resolved).toList(),
    _Filter.starred => all.where((t) => t.starred).toList(),
    _Filter.all => all,
  };

  Future<void> _open(SupportThread th) async {
    final updated = await Navigator.push<SupportThread>(
      context,
      MaterialPageRoute(
        builder: (_) => SupportThreadScreen(
          thread: th,
          admin: true,
          initialMessages: widget.initialMessages?[th.id],
        ),
      ),
    );
    if (_offline) {
      if (updated != null) _replace(updated);
      setState(() => _replace(th.copyWith(unread: false)));
    } else {
      _load();
    }
  }

  void _replace(SupportThread th) {
    _threads = [
      for (final x in _threads ?? const <SupportThread>[])
        x.id == th.id ? th : x,
    ];
  }

  Future<void> _star(SupportThread th) async {
    setState(() => _replace(th.copyWith(starred: !th.starred)));
    if (!_offline) {
      final ok = await SupportService.setStarred(th.id, !th.starred);
      if (!ok && mounted) setState(() => _replace(th));
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = _threads;
    return Directionality(
      textDirection: AccountLang.direction,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('support.inboxTitle')),
        ),
        body: all == null
            ? Center(
                child: _failed
                    ? Text(
                        t('support.loadFailed'),
                        style: const TextStyle(color: AppColors.textMuted),
                      )
                    : const CircularProgressIndicator(color: AppColors.gold),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                    child: _filters(all),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.gold,
                      backgroundColor: AppColors.blackCard,
                      onRefresh: _offline ? () async {} : _load,
                      child: Builder(
                        builder: (_) {
                          final shown = _shown(all);
                          if (shown.isEmpty) {
                            return ListView(
                              children: [
                                const SizedBox(height: 80),
                                const Icon(
                                  Icons.inbox_outlined,
                                  color: AppColors.textMuted,
                                  size: 44,
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  t('support.inboxEmpty'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                              ],
                            );
                          }
                          return ListView(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                            children: [
                              for (final th in shown) ...[
                                _row(th),
                                const SizedBox(height: 8),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Open / solved / starred / all, side by side, each with its count.
  Widget _filters(List<SupportThread> all) {
    final items = [
      (
        _Filter.open,
        t('support.filterOpen'),
        all.where((t) => !t.resolved).length,
      ),
      (
        _Filter.resolved,
        t('support.filterResolved'),
        all.where((t) => t.resolved).length,
      ),
      (
        _Filter.starred,
        t('support.filterStarred'),
        all.where((t) => t.starred).length,
      ),
      (_Filter.all, t('support.filterAll'), all.length),
    ];
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.blackSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.goldBorder),
      ),
      child: Row(
        children: [
          for (final (f, label, count) in items)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _filter = f),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: f == _filter ? AppColors.gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '$label ($count)',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: f == _filter
                          ? AppColors.black
                          : AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: f == _filter
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(SupportThread th) {
    final who = th.name ?? th.email ?? t('support.guest');
    return InkWell(
      onTap: () => _open(th),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: th.unread ? AppColors.gold : AppColors.goldBorder,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                categoryIcon(th.category),
                color: AppColors.gold,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          who,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: th.unread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text(
                        shortWhen(th.lastMessageAt),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  if (th.lastBody != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      th.lastBody!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        categoryLabel(th.category),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(resolved: th.resolved),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: t('support.star'),
              onPressed: () => _star(th),
              icon: Icon(
                th.starred ? Icons.star : Icons.star_border,
                color: th.starred ? AppColors.gold : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
