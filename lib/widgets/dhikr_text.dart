import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// Display names for the machine-translated languages a caller may pass in
/// [DhikrText.moreTranslations], in picker order.
const _moreLanguageNames = <String, String>{
  'fr': 'Français',
  'ur': 'اردو',
  'id': 'Indonesia',
  'ms': 'Bahasa Melayu',
  'hi': 'हिन्दी',
  'tr': 'Türkçe',
  'bn': 'বাংলা',
  'ha': 'Hausa',
};

/// A dhikr's Arabic text with an inline translation toggle.
///
/// Used everywhere a dhikr/dua is read — the adhkar cards, Hisn al-Muslim
/// chapters, and the Umrah guide. With only [english] set, it behaves as a
/// plain English on/off toggle. When [moreTranslations] is also given (Hisn
/// al-Muslim and the Umrah guide, which share its data), the toggle becomes
/// a language picker covering English plus every language in
/// [moreTranslations]; non-English choices are Claude AI machine
/// translations, disclosed under the text. Silently renders Arabic-only
/// when both are null/empty.
class DhikrText extends StatefulWidget {
  final String arabic;
  final String? english;

  /// Machine translations keyed by language code (not including 'en').
  final Map<String, String>? moreTranslations;

  final double fontSize;
  final Color color;
  final TextAlign textAlign;

  const DhikrText({
    super.key,
    required this.arabic,
    required this.english,
    this.moreTranslations,
    required this.fontSize,
    required this.color,
    this.textAlign = TextAlign.right,
  });

  @override
  State<DhikrText> createState() => _DhikrTextState();
}

class _DhikrTextState extends State<DhikrText> {
  String? _activeLang;

  Map<String, String> get _all => {
        if (widget.english != null) 'en': widget.english!,
        ...?widget.moreTranslations,
      };

  bool get _hasMultipleLanguages => widget.moreTranslations?.isNotEmpty ?? false;

  void _toggleSimple() {
    setState(() => _activeLang = _activeLang == null ? 'en' : null);
  }

  void _pickLanguage() {
    final all = _all;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text('اختر لغة الترجمة',
                    style: TextStyle(color: AppColors.gold, fontSize: 15)),
              ),
              if (all['en'] != null)
                _langTile(ctx, 'en', 'English'),
              for (final code in _moreLanguageNames.keys)
                if (all[code] != null)
                  _langTile(ctx, code, _moreLanguageNames[code]!),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langTile(BuildContext ctx, String code, String name) {
    final selected = code == _activeLang;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.gold : AppColors.textMuted,
        size: 19,
      ),
      title: Text(name,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 14)),
      onTap: () {
        Navigator.pop(ctx);
        setState(() => _activeLang = code);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = _activeLang;
    final activeText = active == null ? null : _all[active];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          widget.arabic,
          textAlign: widget.textAlign,
          textDirection: TextDirection.rtl,
          style: TextStyle(
              color: widget.color, fontSize: widget.fontSize, height: 1.9),
        ),
        if (_all.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: _hasMultipleLanguages ? _pickLanguage : _toggleSimple,
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate,
                      size: 15,
                      color:
                          active != null ? AppColors.gold : AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    active == null
                        ? 'Translation'
                        : (active == 'en' ? 'English' : _moreLanguageNames[active]!),
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          active != null ? AppColors.gold : AppColors.textMuted,
                    ),
                  ),
                  if (_hasMultipleLanguages) ...[
                    const SizedBox(width: 2),
                    Icon(Icons.arrow_drop_down,
                        size: 16,
                        color: active != null
                            ? AppColors.gold
                            : AppColors.textMuted),
                  ],
                ],
              ),
            ),
          ),
          if (activeText != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    activeText,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.left,
                    style: const TextStyle(
                        color: AppColors.textGold,
                        fontSize: 13.5,
                        height: 1.55),
                  ),
                  if (active != 'en') ...[
                    const SizedBox(height: 6),
                    const Text(
                      'ترجمة آلية بواسطة Claude AI — وليست ترجمة معتمدة',
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                          color: AppColors.textMuted, fontSize: 10),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
