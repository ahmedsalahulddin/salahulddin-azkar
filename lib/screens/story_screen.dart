import 'package:flutter/material.dart';
import '../constants/theme.dart';
import '../data/stories_data.dart';
import '../l10n/strings.dart';
import '../services/app_locale.dart';
import '../widgets/speak_button.dart';

/// One story: its full text, read aloud on request by the device's voice,
/// with an optional switch to any language it has been translated into.
class StoryScreen extends StatefulWidget {
  final Story story;

  const StoryScreen({super.key, required this.story});

  @override
  State<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends State<StoryScreen> {
  // Opens in the app's own language when this story has been translated
  // into it, rather than always in Arabic until the reader picks again.
  late String _lang = translationFor(widget.story.id, AppLocale.code) != null
      ? AppLocale.code
      : 'ar';

  StoryTranslation? get _translation =>
      _lang == 'ar' ? null : translationFor(widget.story.id, _lang);

  String get _title => _translation?.title ?? widget.story.title;
  String get _body => _translation?.body ?? widget.story.body;
  String get _source => _translation?.source ?? widget.story.source;
  bool get _isArabic => _translation == null;

  void _pickLang() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  t('crd.storyLanguageSheetTitle'),
                  style: const TextStyle(color: AppColors.gold, fontSize: 15),
                ),
              ),
              ListTile(
                leading: Icon(
                  _lang == 'ar'
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: _lang == 'ar' ? AppColors.gold : AppColors.textMuted,
                  size: 19,
                ),
                title: Text(
                  t('crd.arabicOriginalOption'),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _lang = 'ar');
                },
              ),
              for (final (code, name) in supportedStoryLanguages)
                Builder(
                  builder: (_) {
                    final has = translationFor(widget.story.id, code) != null;
                    return ListTile(
                      enabled: has,
                      leading: Icon(
                        _lang == code
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                        color: !has
                            ? AppColors.textMuted.withValues(alpha: 0.3)
                            : _lang == code
                            ? AppColors.gold
                            : AppColors.textMuted,
                        size: 19,
                      ),
                      title: Text(
                        has ? name : '$name (${t('crd.comingSoon')})',
                        style: TextStyle(
                          color: has
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                          fontSize: 14,
                        ),
                      ),
                      onTap: !has
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              setState(() => _lang = code);
                            },
                    );
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.black,
        appBar: AppBar(
          title: Text(_title, maxLines: 1, overflow: TextOverflow.ellipsis),
          backgroundColor: AppColors.black,
          foregroundColor: AppColors.gold,
          actions: [
            TextButton.icon(
              icon: const Icon(Icons.language, size: 17),
              label: Text(
                _isArabic
                    ? t('crd.arabicLanguageLabel')
                    : supportedStoryLanguages
                          .firstWhere((l) => l.$1 == _lang)
                          .$2,
                style: const TextStyle(fontSize: 13),
              ),
              style: TextButton.styleFrom(foregroundColor: AppColors.gold),
              onPressed: _pickLang,
            ),
            if (_isArabic)
              SpeakButton(
                id: widget.story.id,
                text: '$_title. $_body',
                size: 22,
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.blackCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.goldBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _body,
                    textAlign: _isArabic ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      height: 2.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                        top: BorderSide(color: AppColors.goldBorder),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '📖 $_source',
                          textAlign: _isArabic
                              ? TextAlign.right
                              : TextAlign.left,
                          style: const TextStyle(
                            color: AppColors.textGold,
                            fontSize: 12,
                          ),
                        ),
                        if (_translation != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Translated by ${_translation!.translator}',
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _isArabic
                  ? 'القصة مرويّة بأسلوب مبسّط؛ نص الآيات والأحاديث كما وردت '
                        'موجود في قسمَي القرآن والأحاديث بالتطبيق.'
                  : 'This is a plain-language retelling, machine-translated '
                        'by Claude AI — not a scholarly translation. The Arabic '
                        'original is the version to rely on.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
