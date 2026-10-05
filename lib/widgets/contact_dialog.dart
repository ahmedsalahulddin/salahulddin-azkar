import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';
import '../services/translation_feedback_service.dart';

const _contactEmail = 'ahmed.salahulddin@gmail.com';

/// A message to the app's admin, from the About section. It lands in the
/// same admin inbox as translation notes — marked so the two can be told
/// apart there — and an email address is offered beside it for anyone who
/// would rather write from their own mail.
Future<void> showContactDialog(BuildContext context) =>
    showDialog(context: context, builder: (_) => const _ContactDialog());

class _ContactDialog extends StatefulWidget {
  const _ContactDialog();

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
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
    final ok = await TranslationFeedbackService.submit('✉️ $text');
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? t('contact.sent') : t('contact.failed')),
        backgroundColor: ok ? AppColors.emerald : AppColors.error,
      ),
    );
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.blackCard,
      title: Text(
        t('contact.title'),
        style: const TextStyle(color: AppColors.gold),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t('contact.prompt'),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 5,
              maxLength: 1900,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: t('contact.hint'),
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.black,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.goldBorder),
                ),
              ),
            ),
            Text(
              t('contact.orEmail'),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            GestureDetector(
              onTap: () => launchUrl(
                Uri.parse('mailto:$_contactEmail'),
                mode: LaunchMode.externalApplication,
              ),
              child: const Text(
                _contactEmail,
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  color: AppColors.gold,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.gold,
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
        FilledButton(
          onPressed: _sending ? null : _send,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.gold,
            foregroundColor: AppColors.black,
          ),
          child: Text(_sending ? '…' : t('langNotice.send')),
        ),
      ],
    );
  }
}
