import 'package:flutter/material.dart';
import '../constants/theme.dart';

/// A dhikr's Arabic text with an optional inline English-translation toggle.
/// Used everywhere a dhikr/dua is read — the adhkar cards, Hisn al-Muslim
/// chapters, and the Umrah guide — so the toggle looks and behaves the same
/// everywhere. Silently renders Arabic-only when [english] is null.
class DhikrText extends StatefulWidget {
  final String arabic;
  final String? english;
  final double fontSize;
  final Color color;
  final TextAlign textAlign;

  const DhikrText({
    super.key,
    required this.arabic,
    required this.english,
    required this.fontSize,
    required this.color,
    this.textAlign = TextAlign.right,
  });

  @override
  State<DhikrText> createState() => _DhikrTextState();
}

class _DhikrTextState extends State<DhikrText> {
  bool _showEnglish = false;

  @override
  Widget build(BuildContext context) {
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
        if (widget.english != null) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => setState(() => _showEnglish = !_showEnglish),
              behavior: HitTestBehavior.opaque,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.translate,
                      size: 15,
                      color: _showEnglish
                          ? AppColors.gold
                          : AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    'Translation',
                    style: TextStyle(
                      fontSize: 11,
                      color: _showEnglish
                          ? AppColors.gold
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showEnglish) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.goldMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.english!,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.left,
                style: const TextStyle(
                    color: AppColors.textGold, fontSize: 13.5, height: 1.55),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
