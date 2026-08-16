import 'dart:io';
import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../data/ayah_boxes.dart';
import '../../data/quran_data.dart';
import '../../services/mushaf_image_service.dart';
import '../../widgets/frame_tuning.dart';
import '../../widgets/mushaf_chrome.dart';
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
  /// The paper's own inset, which rounds its corners away from the screen.
  static const _sheetMargin = 3.0;

  late Future<File?> _image;
  List<AyahBoxes> _boxes = const [];

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
    return ValueListenableBuilder<int>(
      // Redraws while the tuning panel is open, so a drag is seen as it
      // happens rather than after the page is left and come back to.
      valueListenable: FrameTuning.revision,
      builder: (context, tuning, _) => ValueListenableBuilder<MushafPalette>(
        valueListenable: MushafPalettes.current,
        builder: (context, palette, _) => ValueListenableBuilder<MushafFrame>(
          valueListenable: MushafFrames.current,
          builder: (context, frame, _) => Container(
          margin: const EdgeInsets.all(_sheetMargin),
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
              final band = frame.insetFor(size) * FrameTuning.of('scale');

              // The screen is three parts and nothing else: the top bar, the
              // page, the bottom bar. The border sits on the bottom edge of
              // one and the top edge of the other, and the ayat fill
              // everything between — so the bars are not covering the border,
              // they are where it begins and ends.
              // Both bars are measured from the edge of the screen, while
              // everything here is laid out inside the sheet's own margin —
              // so that margin comes off, or the border sits three low.
              MushafChrome.seed(MediaQuery.viewPaddingOf(context));
              final chromeTop =
                  (MushafChrome.topHeight.value - _sheetMargin).clamp(0.0, size.height);
              final chromeBottom =
                  (MushafChrome.bottomHeight.value - _sheetMargin).clamp(0.0, size.height);

              return Stack(
                // Expand, or the page is handed loose constraints and sizes
                // itself to the image's own thousand-odd pixels. It then lays
                // out against a box that is not the one on screen, and every
                // tap maps to the wrong ayah — which is how the action bar
                // stopped responding.
                fit: StackFit.expand,
                children: [
                  Padding(
                    // Named so a test can read where the page actually landed
                    // rather than assume the knobs reached it.
                    key: const Key('mushaf-page-inset'),
                    padding: EdgeInsets.fromLTRB(
                      0,
                      (chromeTop + FrameTuning.of('top'))
                          .clamp(0.0, size.height / 3),
                      0,
                      (chromeBottom + FrameTuning.of('bottom'))
                          .clamp(0.0, size.height / 3),
                    ),
                    child: _page(palette),
                  ),
                  _frame(frame, palette, band, size, chromeTop, chromeBottom),
                ],
                );
              },
            ),
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
          ),
        );
      },
    );
  }

  /// The border, drawn between the two bars.
  ///
  /// The Uthmanic face the page itself is set in.
  static const _mushafFont = 'AmiriQuran';

  /// How tall a caption sits, independent of how deep the border is. Sized to
  /// the type below rather than guessed at, or the taller face is clipped.
  static const _captionHeight = 26.0;

  /// The caption box grows with the type inside it, or a larger face is
  /// clipped by a box sized for the default one.
  double get _captionBox =>
      _captionHeight + (FrameTuning.of('caption') - 16).clamp(0.0, 14.0);

  Widget _frame(MushafFrame frame, MushafPalette palette, double band,
      Size size, double chromeTop, double chromeBottom) {
    final surah = widget.surahInfo(widget.page.runs.first.surah);
    // The Mushaf's own face, a size above the ayah text: these are the page's
    // own markings, and setting them in the interface font made them read as
    // labels stuck onto the sheet rather than printed with it.
    final caption = TextStyle(
      fontFamily: _mushafFont,
      color: palette.onPaperMuted,
      fontSize: FrameTuning.of('caption'),
      height: 1.15,
    );

    // Pinned to the bars rather than to where the printed image happened to
    // land: a border that follows the image sits somewhere different on every
    // page.
    //
    // And tucked into them by its own depth: the ornament ends where the top
    // bar ends and begins where the bottom bar begins, rather than starting
    // below one and finishing above the other. So the band lies behind the
    // bars while they are up — which costs nothing, since the bar already
    // carries the surah, the juz and the page number the band would repeat —
    // and the whole ornament comes into view the moment the chrome is tapped
    // away.
    final top = (chromeTop - band).clamp(0.0, size.height);
    final bottom = (chromeBottom - band).clamp(0.0, size.height);
    final height = (size.height - top - bottom).clamp(0.0, size.height);

    // Where the markings sit on the band.
    //
    // Centred in the depth of the ornament, the way a printed page sets them:
    // the surah at the top right, the juz at the top left, the number centred
    // below. Since the band is tucked into the bars, so are these while the
    // chrome is up — and they read as part of the border the moment it is
    // tapped away, which is when the border is there to be looked at. Nothing
    // is lost meanwhile: the top bar carries the same three.
    final headerCentre = chromeTop - band / 2;
    final numberCentre = chromeBottom - band / 2;
    return Positioned.fill(
      // Decoration only. Without this the border sits over the page and eats
      // the taps that select an ayah.
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              key: const Key('mushaf-frame-box'),
              left: 0,
              right: 0,
              top: top,
              height: height,
              child: Stack(
                children: [
                  // How far the ornament hangs off each side. Painted wider
                  // than the page by default so its flanks fall out of view —
                  // a Mushaf page cannot spare width from its ayahs — but a
                  // reader who wants the sides shown pulls it back in.
                  Positioned(
                    left: -band + FrameTuning.of('side'),
                    right: -band + FrameTuning.of('side'),
                    top: 0,
                    bottom: 0,
                    child: CustomPaint(
                      key: const Key('mushaf-frame-paint'),
                      painter: MushafFramePainter(
                        frame: frame,
                        color: palette.ink,
                        scale: frame.scaleFor(size) * FrameTuning.of('scale'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Surah on the right, juz on the left — the printed page's own
            // header, each in its own cartouche.
            Positioned(
              top: headerCentre - _captionBox / 2 + FrameTuning.of('header'),
              left: 0,
              right: 0,
              height: _captionBox,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                // Flexible, not fixed: surah names run from الفيل to
                // المطففين, and a box sized for the short one truncates the
                // long one. Each takes what it needs and the row shares out
                // the rest.
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: _cartouche(surah.name, palette, caption),
                    ),
                    const SizedBox(width: 8),
                    _cartouche(
                        'الجزء ${QuranService.toArabicDigits(widget.page.juz)}',
                        palette,
                        caption),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom:
                  numberCentre - _captionBox / 2 - FrameTuning.of('number'),
              left: 0,
              right: 0,
              height: _captionBox,
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
        // Shrinks its own type before it clips: a surah's name is not a
        // detail worth losing the end of.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(text, style: caption, textAlign: TextAlign.center),
        ),
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
