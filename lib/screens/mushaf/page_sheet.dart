import 'dart:io';
import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../data/ayah_boxes.dart';
import '../../data/quran_data.dart';
import '../../services/mushaf_image_service.dart';
import '../../widgets/mushaf_frames.dart';
import '../../widgets/mushaf_palettes.dart';
import '../../widgets/mushaf_page_view.dart';

/// One page of the Mushaf: the printed image inside the reader's chosen border,
/// or — when the image cannot be had — the bundled text set on the same paper.
class MushafPageSheet extends StatefulWidget {
  final MushafPage page;
  final SurahInfo Function(int) surahInfo;
  final AyahBoxes? selected;
  final ValueChanged<AyahBoxes?> onAyahTapped;
  final VoidCallback onBackgroundTapped;

  const MushafPageSheet({
    super.key,
    required this.page,
    required this.surahInfo,
    required this.selected,
    required this.onAyahTapped,
    required this.onBackgroundTapped,
  });

  @override
  State<MushafPageSheet> createState() => _MushafPageSheetState();
}

class _MushafPageSheetState extends State<MushafPageSheet> {
  late Future<File?> _image;
  List<AyahBoxes> _boxes = const [];

  /// Where the printed page landed, so the border can sit on its first and
  /// last lines instead of on the edges of the screen.
  Rect? _drawn;

  @override
  void initState() {
    super.initState();
    _image = MushafImageService.fetch(widget.page.number);
    AyahBoxService.forPage(widget.page.number).then((b) {
      if (mounted) setState(() => _boxes = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    // The page sits inside the reader's chosen border, drawn in the app's own
    // colour so changing the theme carries the ornament with it. The page
    // images are text on a transparent ground with no printed border of their
    // own, so nothing is being drawn over.
    return ValueListenableBuilder<MushafPalette>(
      valueListenable: MushafPalettes.current,
      builder: (context, palette, _) => ValueListenableBuilder<MushafFrame>(
        valueListenable: MushafFrames.current,
        builder: (context, frame, _) => Container(
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: palette.paper,
            borderRadius: BorderRadius.circular(6),
          ),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              // Exactly what the ornament needs, and no more. Inflating this
              // to fit the captions gave them a line of their own and pushed
              // the page up off centre; they are drawn over the border now,
              // on its own level, the way a printed page prints them.
              final band = frame.insetFor(size);

              return Stack(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: band),
                    child: _page(palette),
                  ),
                  _frame(frame, palette, band, size),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _page(MushafPalette palette) {
    return FutureBuilder<File?>(
      future: _image,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Center(
            child:
                CircularProgressIndicator(color: palette.ink, strokeWidth: 2),
          );
        }
        final file = snapshot.data;
        if (file == null) return _textFallback(palette);

        return InvertedInk(
          active: palette.invert,
          child: MushafPageImage(
            file: file,
            boxes: _boxes,
            selected: widget.selected,
            onAyahTapped: widget.onAyahTapped,
            onBackgroundTapped: widget.onBackgroundTapped,
            onDrawn: (rect) {
              if (mounted && rect != _drawn) setState(() => _drawn = rect);
            },
          ),
        );
      },
    );
  }

  /// The border, sitting directly on the first and last lines of the page.
  ///
  /// Published pages differ in height, so the band positions come from where
  /// the image actually landed rather than from the space it was offered —
  /// otherwise the border would float somewhere above the text on a short page
  /// and the whole point of a border would be lost.
  /// How tall a caption sits, independent of how deep the border is.
  static const _captionHeight = 17.0;

  Widget _frame(
      MushafFrame frame, MushafPalette palette, double band, Size size) {
    final drawn = _drawn;
    final top = (drawn?.top ?? 0) + band;
    final bottom = (drawn?.bottom ?? size.height - band * 2) + band;

    final surah = widget.surahInfo(widget.page.runs.first.surah);
    final caption = TextStyle(
        color: palette.onPaperMuted, fontSize: 11.5, height: 1.1);

    return Positioned(
      left: 0,
      right: 0,
      top: (top - band).clamp(0.0, size.height),
      height: (bottom - top + band * 2).clamp(0.0, size.height),
      // Decoration only. Without this the border sits over the page and eats
      // the taps that select an ayah.
      child: IgnorePointer(
        child: Stack(
          children: [
            // Painted wider than the page so the ornament's flanks fall out of
            // view; a Mushaf page cannot spare width from its ayahs.
            Positioned(
              left: -band,
              right: -band,
              top: 0,
              bottom: 0,
              child: CustomPaint(
                painter: MushafFramePainter(
                  frame: frame,
                  color: palette.ink,
                  scale: frame.scaleFor(size),
                ),
              ),
            ),
            // Surah on the right, juz on the left — the printed page's header,
            // each set into the border in its own cartouche.
            // Centred on the border rather than housed inside it: a thin
            // keyline has no room to house anything, and the page's own
            // margin behind it is blank.
            Positioned(
              top: band / 2 - _captionHeight / 2,
              left: 0,
              right: 0,
              height: _captionHeight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    _cartouche(surah.name, palette, caption),
                    const Spacer(),
                    _cartouche(
                        'الجزء ${QuranService.toArabicDigits(widget.page.juz)}',
                        palette,
                        caption),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: band / 2 - _captionHeight / 2,
              left: 0,
              right: 0,
              height: _captionHeight,
              child: Center(
                child: _cartouche(
                    QuranService.toArabicDigits(widget.page.number),
                    palette,
                    caption),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A label set into the border, the way the printed page carries its surah
  /// name and its page number.
  ///
  /// The box is filled with the paper rather than left transparent: that is
  /// what breaks the ornament behind it and makes the label read as part of
  /// the border instead of as writing laid over it. The double rule is the
  /// printed convention — a single line looks like a text field.
  Widget _cartouche(String text, MushafPalette palette, TextStyle caption) {
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        color: palette.paper,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: palette.ink.withValues(alpha: 0.55)),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: palette.ink.withValues(alpha: 0.28)),
        ),
        child: Text(text, style: caption, textAlign: TextAlign.center),
      ),
    );
  }

  /// The bundled text, for when the printed page cannot be fetched.
  ///
  /// Every colour here comes from the paper. The printed page can afford fixed
  /// ink because it is inverted wholesale on a dark sheet; this text is drawn
  /// by the app, so on a dark paper fixed ink would be black on near-black.
  Widget _textFallback(MushafPalette palette) {
    final view = MediaQuery.viewPaddingOf(context);
    return GestureDetector(
      onTap: widget.onBackgroundTapped,
      child: SingleChildScrollView(
        // Clears the two-row bar above and the action bar below, plus the
        // system bars.
        padding: EdgeInsets.fromLTRB(16, 80 + view.top, 16, 62 + view.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final run in widget.page.runs) ..._runWidgets(run, palette),
            const SizedBox(height: 8),
            Text('صفحة ${QuranService.toArabicDigits(widget.page.number)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: palette.onPaperMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  List<Widget> _runWidgets(AyahRun run, MushafPalette palette) {
    final info = widget.surahInfo(run.surah);
    return [
      if (run.startsSurah) ...[
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: palette.ink.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: palette.ink.withValues(alpha: 0.45)),
          ),
          child: Text('سورة ${info.name}',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: palette.ink,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
        ),
        if (info.hasBasmala)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(QuranService.basmala,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: mushafFont,
                  color: palette.ink,
                  fontSize: 20,
                  height: 1.9,
                )),
          ),
      ],
      FutureBuilder<Surah>(
        future: QuranService.surah(run.surah),
        builder: (context, snapshot) {
          final surah = snapshot.data;
          if (surah == null) return const SizedBox(height: 40);
          return Text.rich(
            TextSpan(children: [
              for (var n = run.first; n <= run.last; n++) ...[
                TextSpan(text: surah.ayahs[n - 1].text),
                TextSpan(
                  text: ' ﴿${QuranService.toArabicDigits(n)}﴾ ',
                  style: TextStyle(color: palette.ink, fontSize: 15),
                ),
              ],
            ]),
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontFamily: mushafFont,
              color: palette.onPaper,
              fontSize: 21,
              height: 2.2,
            ),
          );
        },
      ),
      const SizedBox(height: 6),
    ];
  }
}
