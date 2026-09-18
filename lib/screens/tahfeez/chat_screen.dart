import 'dart:async';

import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/auth_service.dart';
import '../../services/tahfeez_service.dart';
import 'tahfeez_widgets.dart';

/// The thread between the two sides of one enrolment. Everything stays on
/// the server; a long press on the other side's message reports it.
class ChatScreen extends StatefulWidget {
  final Enrollment enrollment;

  const ChatScreen({super.key, required this.enrollment});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messages = <TahfeezMessage>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  StreamSubscription<TahfeezMessage>? _sub;
  bool _loading = true;
  bool _sending = false;

  String get _uid => AuthService.user.value!.id;

  TahfeezProfile? get _other => widget.enrollment.teacherId == _uid
      ? widget.enrollment.student
      : widget.enrollment.teacher;

  @override
  void initState() {
    super.initState();
    _load();
    _sub = TahfeezService.messageStream(widget.enrollment.id).listen((m) {
      if (!mounted || _messages.any((x) => x.id == m.id)) return;
      setState(() => _messages.add(m));
      _jumpToEnd();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final list = await TahfeezService.messages(widget.enrollment.id);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
        _loading = false;
      });
      _jumpToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showNote(context, describeError(e), error: true);
    }
  }

  void _jumpToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await TahfeezService.sendMessage(widget.enrollment.id, body);
      if (!mounted) return;
      _input.clear();
      if (!_messages.any((x) => x.id == m.id)) {
        setState(() => _messages.add(m));
      }
      _jumpToEnd();
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _report(TahfeezMessage m) async {
    final reason = await promptText(
      context,
      title: t('tahfeez.report'),
      subtitle: m.body,
      hint: t('tahfeez.reportReasonHint'),
      confirmLabel: t('tahfeez.report'),
      maxLines: 2,
    );
    if (reason == null || !mounted) return;
    try {
      await TahfeezService.reportMessage(m.id, reason);
      if (mounted) showNote(context, t('tahfeez.reported'));
    } catch (e) {
      if (mounted) showNote(context, describeError(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final other = _other;
    final photo = other?.photoUrl;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.goldMuted,
                backgroundImage: photo != null ? NetworkImage(photo) : null,
                child: photo == null
                    ? const Icon(Icons.person, color: AppColors.gold, size: 16)
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  other?.displayName ?? t('tahfeez.chat'),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: AppColors.blackCard,
              child: Text(
                t('tahfeez.messagesKept'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    )
                  : _messages.isEmpty
                  ? EmptyNote(
                      icon: Icons.chat_bubble_outline,
                      text: t('tahfeez.noMessages'),
                    )
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) => _bubble(_messages[i]),
                    ),
            ),
            _composer(),
          ],
        ),
      ),
    );
  }

  Widget _bubble(TahfeezMessage m) {
    final mine = m.senderId == _uid;
    final time = TimeOfDay.fromDateTime(m.createdAt);
    return Align(
      alignment: mine ? Alignment.centerLeft : Alignment.centerRight,
      child: GestureDetector(
        onLongPress: mine ? null : () => _report(m),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: mine ? AppColors.emeraldMuted : AppColors.blackCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: mine ? AppColors.emerald : AppColors.goldBorder,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                m.body,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                formatTime(time),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        10,
        8,
        10,
        8 + MediaQuery.of(context).viewPadding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.blackCard,
        border: Border(top: BorderSide(color: AppColors.goldBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _send(),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
              decoration: InputDecoration(
                hintText: t('tahfeez.messageHint'),
                hintStyle: const TextStyle(color: AppColors.textMuted),
                isDense: true,
                filled: true,
                fillColor: AppColors.blackSurface,
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppColors.gold),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sending ? null : _send,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.black,
            ),
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.black,
                    ),
                  )
                : const Icon(Icons.send, size: 18),
          ),
        ],
      ),
    );
  }
}
