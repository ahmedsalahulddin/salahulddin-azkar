import 'package:flutter/material.dart';

import '../../constants/theme.dart';

/// A book's page: Qur'an quotations ﴿…﴾ in the mushaf's gold, references
/// like [البقرة: ١٢] muted, the rest as plain reading text. Selectable, so a
/// reader can copy a passage.
class ResearcherText extends StatelessWidget {
  final String text;
  final double fontSize;

  const ResearcherText(this.text, {super.key, this.fontSize = 15.5});

  static final _parts = RegExp(
    r'(﴿[^﴾]*﴾)|(\[[^\[\]\n]{1,40}:\s*[٠-٩0-9\-– ،,]+\])',
  );

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var last = 0;
    for (final m in _parts.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(0),
          style: m.group(1) != null
              ? TextStyle(
                  color: AppColors.textGold,
                  fontFamily: 'AmiriQuran',
                  fontSize: fontSize + 1,
                )
              : const TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
      );
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return SelectableText.rich(
      TextSpan(
        children: spans,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: fontSize,
          height: 1.85,
        ),
      ),
    );
  }
}
