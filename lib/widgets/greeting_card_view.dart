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

  /// Where the signature block sits, on a three-by-four grid over the card:
  /// [signColumn] runs 0..2 from the right, [signRow] 0..3 from the top.
  final int signColumn;
  final int signRow;

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
    this.signColumn = 1,
    this.signRow = 3,
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
                child: Stack(
                  children: [
                    if (forSharing)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Text(
                          'islamic-azkar.yallanow.app',
                          style: TextStyle(
                            color: palette.muted,
                            fontSize: 9 * unit,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    _signature(palette, unit),
                    Column(
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
                  ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// The sender's line and name, floated on the cell they chose. Rows run
  /// top to bottom, columns right to left — the way the picker shows them.
  Widget _signature(CardPalette palette, double unit) {
    final name = senderName?.trim() ?? '';
    final note = senderNote?.trim() ?? '';
    if (name.isEmpty && note.isEmpty) return const SizedBox.shrink();

    const xs = [1.0, 0.0, -1.0];
    const ys = [-0.97, -0.35, 0.35, 0.97];
    var y = ys[signRow.clamp(0, 3)];
    // The bottom row would sit on the app's address when sharing.
    if (forSharing && signRow == 3) y = 0.80;

    return Align(
      alignment: Alignment(xs[signColumn.clamp(0, 2)], y),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note.isNotEmpty)
            Text(
              note,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.body,
                fontSize: 12.5 * unit,
                height: 1.6,
              ),
            ),
          if (name.isNotEmpty) ...[
            SizedBox(height: 3 * unit),
            Text(
              'المرسل: $name',
              style: TextStyle(
                color: palette.muted,
                fontSize: 11 * unit,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
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
