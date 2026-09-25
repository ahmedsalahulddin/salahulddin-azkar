import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';
import '../services/translation_feedback_service.dart';

/// What readers wrote after switching languages, newest first.
///
/// Reachable only for accounts listed in app_admins (see AdminScreen).
class AdminTranslationFeedbackScreen extends StatefulWidget {
  const AdminTranslationFeedbackScreen({super.key});

  @override
  State<AdminTranslationFeedbackScreen> createState() =>
      _AdminTranslationFeedbackScreenState();
}

class _AdminTranslationFeedbackScreenState
    extends State<AdminTranslationFeedbackScreen> {
  List<TranslationFeedback> _items = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await TranslationFeedbackService.list();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _delete(TranslationFeedback f) async {
    setState(() => _items = _items.where((i) => i.id != f.id).toList());
    await TranslationFeedbackService.delete(f.id);
  }

  Future<void> _markRead(TranslationFeedback f) async {
    if (f.isRead) return;
    setState(() {
      _items = [
        for (final i in _items)
          if (i.id == f.id)
            TranslationFeedback(
              id: i.id,
              appLang: i.appLang,
              message: i.message,
              isRead: true,
              createdAt: i.createdAt,
            )
          else
            i,
      ];
    });
    await TranslationFeedbackService.markRead(f.id);
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((i) => !i.isRead).length;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(t('admin.feedback.title')),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
        ),
        body: _loading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.gold),
              )
            : _items.isEmpty
            ? Center(
                child: Text(
                  t('admin.feedback.empty'),
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.gold,
                backgroundColor: AppColors.blackCard,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _items.length + 1,
                  itemBuilder: (context, i) {
                    if (i == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Text(
                          unread == 0
                              ? t('admin.feedback.allRead')
                              : t(
                                  'admin.feedback.unreadCount',
                                ).replaceAll('{count}', '$unread'),
                          style: const TextStyle(
                            color: AppColors.textGold,
                            fontSize: 12,
                          ),
                        ),
                      );
                    }
                    return _card(_items[i - 1]);
                  },
                ),
              ),
      ),
    );
  }

  Widget _card(TranslationFeedback f) {
    return Dismissible(
      key: ValueKey(f.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _delete(f),
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => _markRead(f),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.blackCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: f.isRead ? AppColors.goldBorder : AppColors.gold,
              width: f.isRead ? 1 : 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!f.isRead)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.circle, size: 8, color: AppColors.gold),
                    ),
                  Text(
                    AppLocale.nameOf(f.appLang),
                    style: const TextStyle(
                      color: AppColors.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatDate(f.createdAt),
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                f.message,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final local = d.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} ${two(local.hour)}:${two(local.minute)}';
  }
}
