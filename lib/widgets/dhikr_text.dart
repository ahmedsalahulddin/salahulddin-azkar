import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/theme.dart';
import '../l10n/strings.dart';

/// Display names for the machine-translated languages a caller may pass in
/// [DhikrText.moreTranslations], in picker order.
const dhikrMoreLanguageNames = <String, String>{
  'fr': 'Français',
  'ur': 'اردو',
  'id': 'Indonesia',
  'ms': 'Bahasa Melayu',
  'hi': 'हिन्दी',
  'tr': 'Türkçe',
  'bn': 'বাংলা',
  'ha': 'Hausa',
};

/// The reader's chosen dhikr-translation language, shared by every
/// [DhikrText] on screen at once — picked from a single [DhikrLangButton] at
/// the top of the page rather than per card. Null means Arabic-only.
class DhikrLangPref {
  static const _key = '@noor_dhikr_lang';
  static final ValueNotifier<String?> selected = ValueNotifier(null);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    selected.value = prefs.getString(_key);
  }

  static Future<void> set(String? lang) async {
    selected.value = lang;
    final prefs = await SharedPreferences.getInstance();
    if (lang == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, lang);
    }
  }
}

/// An app-bar action that opens a language picker and updates
/// [DhikrLangPref] for every [DhikrText] on screen. Place one per screen
/// that reads adhkar/duas — the Adhkar categories, Hisn al-Muslim chapters,
/// and the Umrah guide all share the same reader preference.
class DhikrLangButton extends StatelessWidget {
  const DhikrLangButton({super.key});

  void _pick(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.blackCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: ValueListenableBuilder<String?>(
            valueListenable: DhikrLangPref.selected,
            builder: (ctx, current, _) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Text(
                    t('adh.translationLanguageTitle'),
                    style: const TextStyle(color: AppColors.gold, fontSize: 15),
                  ),
                ),
                _tile(ctx, null, t('adh.noTranslationOption'), current),
                _tile(ctx, 'en', 'English', current),
                for (final code in dhikrMoreLanguageNames.keys)
                  _tile(ctx, code, dhikrMoreLanguageNames[code]!, current),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext ctx, String? code, String name, String? current) {
    final selected = code == current;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? AppColors.gold : AppColors.textMuted,
        size: 19,
      ),
      title: Text(
        name,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      ),
      onTap: () {
        Navigator.pop(ctx);
        DhikrLangPref.set(code);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: DhikrLangPref.selected,
      builder: (context, lang, _) => TextButton.icon(
        onPressed: () => _pick(context),
        icon: const Icon(Icons.translate, size: 17),
        label: Text(
          lang == null
              ? t('adh.translationButtonLabel')
              : (lang == 'en' ? 'English' : dhikrMoreLanguageNames[lang]!),
          style: const TextStyle(fontSize: 13),
        ),
        style: TextButton.styleFrom(foregroundColor: AppColors.gold),
      ),
    );
  }
}

/// A dhikr's Arabic text, with its translation shown underneath whenever
/// [DhikrLangPref.selected] is set and this dhikr has a rendering in that
/// language. Used everywhere a dhikr/dua is read — the adhkar cards, Hisn
/// al-Muslim chapters, and the Umrah guide — so picking a language once at
/// the top of any of those screens (via [DhikrLangButton]) translates every
/// card on it at once. Non-English translations are Claude AI machine
/// renderings, disclosed under the text; [english] alone is treated as
/// official/hand-translated and carries no such disclosure.
class DhikrText extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: DhikrLangPref.selected,
      builder: (context, lang, _) {
        final activeText = lang == null
            ? null
            : (lang == 'en' ? english : moreTranslations?[lang]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              arabic,
              textAlign: textAlign,
              textDirection: TextDirection.rtl,
              style: TextStyle(color: color, fontSize: fontSize, height: 1.9),
            ),
            if (activeText != null) ...[
              const SizedBox(height: 8),
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
                        height: 1.55,
                      ),
                    ),
                    if (lang != 'en') ...[
                      const SizedBox(height: 6),
                      Text(
                        t('adh.machineTranslationDisclaimer'),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
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
          ],
        );
      },
    );
  }
}
