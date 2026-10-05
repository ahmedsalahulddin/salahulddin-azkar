import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/account_lang.dart';
import '../../services/support_service.dart';
import 'support_widgets.dart';

/// One request as a conversation. The reader sees their messages and the
/// admins' replies; an admin also gets the star and the solved switch.
class SupportThreadScreen extends StatefulWidget {
  final SupportThread thread;
  final bool admin;

  /// Messages to show instead of fetching, and no network on actions — for
  /// previews only.
  @visibleForTesting
  final List<SupportMessage>? initialMessages;

  const SupportThreadScreen({
    super.key,
    required this.thread,
    this.admin = false,
    this.initialMessages,
  });

  @override
  State<SupportThreadScreen> createState() => _SupportThreadScreenState();
}

class _SupportThreadScreenState extends State<SupportThreadScreen> {
  late SupportThread _thread = widget.thread;
  List<SupportMessage>? _messages;
  bool _failed = false;
  bool _sending = false;
  final _reply = TextEditingController();
  final _scroll = ScrollController();

  bool get _offline => widget.initialMessages != null;

  @override
  void initState() {
    super.initState();
    if (_offline) {
      _messages = widget.initialMessages;
    } else {
      _load();
      if (_thread.unread) SupportService.markRead(_thread.id);
    }
  }

  @override
  void dispose() {
    _reply.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final list = await SupportService.messages(_thread.id);
    if (!mounted) return;
    setState(() {
      _messages = list ?? _messages;
      _failed = list == null;
    });
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _reply.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    final ok = _offline || await SupportService.reply(_thread.id, text);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      _say(t('support.sendFailed'));
      return;
    }
    _reply.clear();
    if (_offline) {
      setState(() {
        _messages = [
          ...?_messages,
          SupportMessage(
            id: DateTime.now().millisecondsSinceEpoch,
            fromAdmin: widget.admin,
            body: text,
            createdAt: DateTime.now(),
          ),
        ];
      });
      _toBottom();
    } else {
      await _load();
    }
    // A reader writing again reopens a solved request.
    if (!widget.admin && _thread.resolved) {
      setState(() => _thread = _thread.copyWith(resolved: false));
    }
  }

  Future<void> _toggleResolved() async {
    final next = !_thread.resolved;
    setState(() => _thread = _thread.copyWith(resolved: next));
    final ok = _offline || await SupportService.setResolved(_thread.id, next);
    if (!mounted) return;
    if (!ok) {
      setState(() => _thread = _thread.copyWith(resolved: !next));
      _say(t('support.sendFailed'));
    } else {
      _say(next ? t('support.markedResolved') : t('support.markedOpen'));
    }
  }

  Future<void> _toggleStar() async {
    final next = !_thread.starred;
    setState(() => _thread = _thread.copyWith(starred: next));
    final ok = _offline || await SupportService.setStarred(_thread.id, next);
    if (!ok && mounted) {
      setState(() => _thread = _thread.copyWith(starred: !next));
    }
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  @override
  Widget build(BuildContext context) {
    final who = widget.admin
        ? (_thread.name ?? _thread.email ?? t('support.guest'))
        : categoryLabel(_thread.category);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.pop(context, _thread);
      },
      child: Directionality(
        textDirection: AccountLang.direction,
        child: Scaffold(
          backgroundColor: AppColors.black,
          appBar: AppBar(
            backgroundColor: AppColors.black,
            foregroundColor: AppColors.gold,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(who, style: const TextStyle(fontSize: 16)),
                Row(
                  children: [
                    if (widget.admin) ...[
                      Text(
                        categoryLabel(_thread.category),
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    StatusPill(resolved: _thread.resolved),
                  ],
                ),
              ],
            ),
            actions: [
              if (widget.admin)
                IconButton(
                  tooltip: t('support.star'),
                  onPressed: _toggleStar,
                  icon: Icon(
                    _thread.starred ? Icons.star : Icons.star_border,
                    color: AppColors.gold,
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              if (widget.admin && _thread.email != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  color: AppColors.blackSurface,
                  child: Text(
                    _thread.email!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ),
              Expanded(
                child: _messages == null
                    ? Center(
                        child: _failed
                            ? Text(
                                t('support.loadFailed'),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              )
                            : const CircularProgressIndicator(
                                color: AppColors.gold,
                              ),
                      )
                    : ListView(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        children: [for (final m in _messages!) _bubble(m)],
                      ),
              ),
              if (widget.admin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _toggleResolved,
                      icon: Icon(
                        _thread.resolved ? Icons.replay : Icons.check_circle,
                        size: 18,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _thread.resolved
                            ? AppColors.goldLight
                            : AppColors.success,
                        side: BorderSide(
                          color:
                              (_thread.resolved
                                      ? AppColors.goldLight
                                      : AppColors.success)
                                  .withValues(alpha: 0.6),
                        ),
                      ),
                      label: Text(
                        _thread.resolved
                            ? t('support.reopen')
                            : t('support.markResolved'),
                      ),
                    ),
                  ),
                ),
              _composer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubble(SupportMessage m) {
    // My side: the reader's own messages, or an admin's replies in admin view.
    final mine = m.fromAdmin == widget.admin;
    return Align(
      alignment: mine
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? AppColors.goldMuted : AppColors.blackCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: mine
                ? AppColors.gold.withValues(alpha: 0.4)
                : AppColors.goldBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.fromAdmin && !widget.admin)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  t('support.adminName'),
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            Text(
              m.body,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              shortWhen(m.createdAt),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _reply,
                minLines: 1,
                maxLines: 4,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: t('support.replyHint'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  isDense: true,
                  filled: true,
                  fillColor: AppColors.blackCard,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.goldBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(color: AppColors.goldBorder),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.gold,
                foregroundColor: AppColors.black,
              ),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.black,
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
