import 'package:flutter/material.dart';

import '../../constants/theme.dart';
import '../../l10n/strings.dart';
import '../../services/account_lang.dart';
import '../../services/support_service.dart';
import 'support_thread_screen.dart';
import 'support_widgets.dart';

/// The categories a reader can pick when writing; translation notes and the
/// contact form arrive through their own dialogs.
const writableCategories = [
  SupportCategory.edit,
  SupportCategory.teacher,
  SupportCategory.problem,
  SupportCategory.suggestion,
  SupportCategory.other,
];

/// The reader's requests to the admins and the replies to them, with a
/// button to write a new one.
class MyMessagesScreen extends StatefulWidget {
  /// Shown instead of fetching, with sample conversations — previews only.
  @visibleForTesting
  final List<SupportThread>? initialThreads;
  @visibleForTesting
  final Map<String, List<SupportMessage>>? initialMessages;

  const MyMessagesScreen({
    super.key,
    this.initialThreads,
    this.initialMessages,
  });

  @override
  State<MyMessagesScreen> createState() => _MyMessagesScreenState();
}

class _MyMessagesScreenState extends State<MyMessagesScreen> {
  List<SupportThread>? _threads;
  bool _failed = false;

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
    final list = await SupportService.myThreads();
    if (!mounted) return;
    setState(() {
      _threads = list ?? _threads;
      _failed = list == null;
    });
  }

  Future<void> _open(SupportThread th) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SupportThreadScreen(
          thread: th,
          initialMessages: widget.initialMessages?[th.id],
        ),
      ),
    );
    if (!_offline) _load();
  }

  Future<void> _compose() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ComposeSheet(offline: _offline),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('support.sent'))));
      if (!_offline) _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final threads = _threads;
    return Directionality(
      textDirection: AccountLang.direction,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          title: Text(t('support.myTitle')),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _compose,
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.black,
          icon: const Icon(Icons.edit),
          label: Text(t('support.new')),
        ),
        body: threads == null
            ? Center(
                child: _failed
                    ? Text(
                        t('support.loadFailed'),
                        style: const TextStyle(color: AppColors.textMuted),
                      )
                    : const CircularProgressIndicator(color: AppColors.gold),
              )
            : RefreshIndicator(
                color: AppColors.gold,
                backgroundColor: AppColors.blackCard,
                onRefresh: _offline ? () async {} : _load,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                  children: [
                    Text(
                      t('support.mySub'),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (threads.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.forum_outlined,
                              color: AppColors.textMuted,
                              size: 44,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              t('support.myEmpty'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      for (final th in threads) ...[
                        _row(th),
                        const SizedBox(height: 8),
                      ],
                  ],
                ),
              ),
      ),
    );
  }

  Widget _row(SupportThread th) {
    return InkWell(
      onTap: () => _open(th),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.blackCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: th.unread ? AppColors.gold : AppColors.goldBorder,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.goldMuted,
                shape: BoxShape.circle,
              ),
              child: Icon(
                categoryIcon(th.category),
                color: AppColors.gold,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          categoryLabel(th.category),
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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      StatusPill(resolved: th.resolved),
                      if (th.unread) ...[
                        const SizedBox(width: 6),
                        Text(
                          t('support.newReply'),
                          style: const TextStyle(
                            color: AppColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposeSheet extends StatefulWidget {
  final bool offline;
  const _ComposeSheet({required this.offline});

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  SupportCategory _category = SupportCategory.edit;
  final _text = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_text.text.trim().isEmpty) return;
    setState(() => _sending = true);
    final ok =
        widget.offline ||
        await SupportService.open(_category, _text.text) != null;
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t('support.sendFailed'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AccountLang.direction,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          18,
          20,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('support.new'),
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                t('support.aboutWhat'),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in writableCategories)
                    ChoiceChip(
                      avatar: Icon(
                        categoryIcon(c),
                        size: 16,
                        color: c == _category
                            ? AppColors.black
                            : AppColors.gold,
                      ),
                      label: Text(categoryLabel(c)),
                      selected: c == _category,
                      showCheckmark: false,
                      selectedColor: AppColors.gold,
                      backgroundColor: AppColors.blackSurface,
                      side: const BorderSide(color: AppColors.goldBorder),
                      labelStyle: TextStyle(
                        color: c == _category
                            ? AppColors.black
                            : AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 4,
                maxLines: 8,
                maxLength: 4000,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: t('support.writeHint'),
                  hintStyle: const TextStyle(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.blackSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.goldBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.goldBorder),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _sending ? null : _send,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.gold,
                    foregroundColor: AppColors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.send),
                  label: Text(t('support.send')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
