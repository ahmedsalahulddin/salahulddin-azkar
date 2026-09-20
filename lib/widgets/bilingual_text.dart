import 'package:flutter/material.dart';
import '../l10n/strings.dart';

/// Renders a [tBoth] (or [HisnChapter.displayTitle]) string as two lines —
/// the Arabic name, then its English rendering in parentheses below, in a
/// smaller and quieter style. Two lines rather than one that wraps: once a
/// long "Arabic (English)" string no longer fits on one line, Flutter's
/// bidi reordering splits the parenthetical apart mid-phrase, which is
/// unreadable. Renders as a single plain line when there is no English half.
class BilingualText extends StatelessWidget {
  final String combined;
  final TextStyle style;
  final TextStyle? englishStyle;
  final TextAlign textAlign;
  final int maxLines;

  const BilingualText(
    this.combined, {
    super.key,
    required this.style,
    this.englishStyle,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
  });

  CrossAxisAlignment get _crossAlign => switch (textAlign) {
    TextAlign.right => CrossAxisAlignment.end,
    TextAlign.left => CrossAxisAlignment.start,
    _ => CrossAxisAlignment.center,
  };

  @override
  Widget build(BuildContext context) {
    final (ar, en) = splitBilingual(combined);
    final enStyle =
        englishStyle ??
        style.copyWith(
          fontSize: (style.fontSize ?? 14) * 0.8,
          color: style.color?.withValues(alpha: 0.68),
          fontWeight: FontWeight.normal,
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: _crossAlign,
      children: [
        Text(
          ar,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        if (en != null)
          Text(
            '($en)',
            textDirection: TextDirection.ltr,
            textAlign: textAlign,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: enStyle,
          ),
      ],
    );
  }
}
