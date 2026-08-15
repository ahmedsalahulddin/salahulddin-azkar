import 'package:flutter/material.dart';

import '../data/greeting_cards.dart';
import 'mushaf_frames.dart';

/// A card as it will be sent: ground, ornament, greeting, verse, citation.
///
/// The border is the same painter the Mushaf uses. That was the point of
/// drawing those in the first place — an ornament that takes its colour as an
/// argument works just as well on a card meant for someone's phone as it does
/// around a page.
class GreetingCardView extends StatelessWidget {
  final ResolvedCard resolved;

  /// Who is sending it, in their own hand — written onto the card itself, the
  /// way a paper card is signed.
  final String? senderName;

  /// A short personal line the sender may add over the signature.
  final String? senderNote;

  /// True when rendering for export rather than for the screen, which is the
  /// only difference the card makes between the two: the app's name is worth
  /// carrying on a card someone forwards, and is noise on the preview.
  final bool forSharing;

  const GreetingCardView({
    super.key,
    required this.resolved,
    this.forSharing = false,
    this.senderName,
    this.senderNote,
  });

  /// Four by five — the shape that survives a chat app without being cropped.
  static const aspectRatio = 4 / 5;

  @override
  Widget build(BuildContext context) {
    final card = resolved.card;
    final palette = card.palette;

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Everything is sized from the card's own width, so the preview on
          // screen and the exported image are the same drawing at two scales.
          final unit = constraints.maxWidth / 400;

          return DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [palette.top, palette.bottom],
              ),
            ),
            child: CustomPaint(
              painter: MushafFramePainter(
                frame: card.frame,
                color: palette.ink,
                scale: unit,
              ),
              child: Padding(
                padding: EdgeInsets.all(card.frame.insetFor(
                        Size(constraints.maxWidth, constraints.maxHeight)) +
                    10 * unit),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      card.greeting,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 30 * unit,
                        height: 1.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (card.note != null) ...[
                      SizedBox(height: 6 * unit),
                      Text(
                        card.note!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 13 * unit,
                          height: 1.6,
                        ),
                      ),
                    ],
                    SizedBox(height: 22 * unit),
                    _rule(palette, unit),
                    SizedBox(height: 22 * unit),
                    Flexible(
                      // Shrinks rather than clips. A card is a fixed shape and
                      // verses are not a fixed length, so one of the two has
                      // to give — and cutting a verse short is not an option.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: constraints.maxWidth),
                          child: Text(
                            resolved.verse,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'AmiriQuran',
                              color: palette.body,
                              fontSize: 17 * unit,
                              height: 2.1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12 * unit),
                    Text(
                      resolved.citation,
                      style: TextStyle(
                        color: palette.ink,
                        fontSize: 11.5 * unit,
                      ),
                    ),
                    if (senderNote != null && senderNote!.trim().isNotEmpty) ...[
                      SizedBox(height: 14 * unit),
                      Text(
                        senderNote!.trim(),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.body,
                          fontSize: 12.5 * unit,
                          height: 1.6,
                        ),
                      ),
                    ],
                    if (senderName != null && senderName!.trim().isNotEmpty) ...[
                      SizedBox(height: 6 * unit),
                      Text(
                        'المرسل: ${senderName!.trim()}',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11 * unit,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (forSharing) ...[
                      SizedBox(height: 18 * unit),
                      Text(
                        'islamic-azkar.yallanow.app',
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 9 * unit,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// A short divider with a diamond on it, so the greeting and the verse read
  /// as two things rather than one run-on block.
  Widget _rule(CardPalette palette, double unit) {
    return SizedBox(
      height: 8 * unit,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
              width: 46 * unit,
              height: 1 * unit,
              color: palette.ink.withValues(alpha: 0.5)),
          SizedBox(width: 7 * unit),
          Transform.rotate(
            angle: 0.785,
            child: Container(
                width: 5 * unit, height: 5 * unit, color: palette.ink),
          ),
          SizedBox(width: 7 * unit),
          Container(
              width: 46 * unit,
              height: 1 * unit,
              color: palette.ink.withValues(alpha: 0.5)),
        ],
      ),
    );
  }
}
