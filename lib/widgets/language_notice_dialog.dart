import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';
import '../services/translation_feedback_service.dart';

/// Which cards are fully translated, grouped by the shelf they sit under —
/// shown after every language change so a reader knows where to expect
/// their own language and where they might still see Arabic.
///
/// Each entry is (shelf title key, [card title keys]). Kept as a short,
/// hand-picked list of the sections that are *fully* translated content,
/// not every card — a card whose surrounding buttons are translated but
/// whose actual text (a hadith, a greeting card) is still Arabic-only
/// would be misleading to list here.
const _translatedShelves = [
  ('shelf.quran.title', ['card.translation.title']),
  ('shelf.adhkar.title', ['card.sahih.title', 'langNotice.dailyAdhkarCard']),
  ('shelf.stories.title', ['shelf.stories.title']),
  ('shelf.duas.title', ['shelf.duas.title']),
];

/// Shows the language-switch notice, in [code]'s own direction and text.
/// Called right after [AppLocale.set] resolves, every time — not just the
/// first time — since a reader may switch back and forth and each language
/// has its own translated-coverage list.
Future<void> showLanguageNotice(BuildContext context, String code) {
  final isRtl = code == 'ar' || code == 'ur';
  return showDialog<void>(
    context: context,
    builder: (_) => Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: const _LanguageNoticeDialog(),
    ),
  );
}

class _LanguageNoticeDialog extends StatefulWidget {
  const _LanguageNoticeDialog();

  @override
  State<_LanguageNoticeDialog> createState() => _LanguageNoticeDialogState();
}

class _LanguageNoticeDialogState extends State<_LanguageNoticeDialog> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await TranslationFeedbackService.submit(text);
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? t('langNotice.sent') : t('langNotice.sendFailed')),
        backgroundColor: ok ? AppColors.emerald : AppColors.error,
      ),
    );
    if (ok && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.blackCard,
      title: Text(
        t('langNotice.title'),
        style: const TextStyle(color: AppColors.gold),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t('langNotice.intro'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              t('langNotice.translatedIntro'),
              style: const TextStyle(
                color: AppColors.gold,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            for (final (shelfKey, cardKeys) in _translatedShelves)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 16,
                      color: AppColors.emerald,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                          children: [
                            TextSpan(
                              text: t(shelfKey),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: ': ${cardKeys.map(t).toSet().join('، ')}',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            Text(
              t('langNotice.moreComing'),
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 12,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t('langNotice.feedbackPrompt'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: t('langNotice.hint'),
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.black,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.goldBorder),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            t('langNotice.close'),
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
        TextButton(
          onPressed: _sending ? null : _send,
          child: Text(
            _sending ? '…' : t('langNotice.send'),
            style: const TextStyle(
              color: AppColors.gold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
