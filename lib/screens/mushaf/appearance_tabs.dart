import 'package:flutter/material.dart';
import '../../constants/theme.dart';
import '../../widgets/mushaf_frames.dart';
import '../../widgets/mushaf_palettes.dart';

/// Picks the border drawn around the page. Every swatch is the real painter at
/// preview size, so what the reader taps is exactly what the page becomes.
class FrameTab extends StatelessWidget {
  const FrameTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MushafFrame>(
      valueListenable: MushafFrames.current,
      builder: (context, chosen, _) => ValueListenableBuilder<MushafPalette>(
        valueListenable: MushafPalettes.current,
        builder: (context, palette, _) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('إطار الصفحة',
                style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'زخارف مرسومة داخل التطبيق، تأخذ لون السمة وتتغيّر معه.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            SwatchGrid(
              children: [
                for (final frame in MushafFrame.values)
                  Swatch(
                    label: frame.label,
                    active: frame == chosen,
                    palette: palette,
                    frame: frame,
                    onTap: () => MushafFrames.choose(frame),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Picks the paper. Each swatch is that paper with that ornament on it, so
/// the choice is made by looking rather than by reading a colour name.
class PaletteTab extends StatelessWidget {
  const PaletteTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MushafPalette>(
      valueListenable: MushafPalettes.current,
      builder: (context, chosen, _) => ValueListenableBuilder<MushafFrame>(
        valueListenable: MushafFrames.current,
        builder: (context, frame, _) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const Text('لون الصفحة',
                style: TextStyle(
                    color: AppColors.gold,
                    fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
              'الإطار وأرقام الآيات تأخذ لون الورقة. الأوراق الداكنة تقلب لون '
              'الخط ليبقى مقروءاً.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 12),
            SwatchGrid(
              children: [
                for (final palette in MushafPalette.values)
                  Swatch(
                    label: palette.label,
                    active: palette == chosen,
                    palette: palette,
                    frame: frame,
                    onTap: () => MushafPalettes.choose(palette),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Three to a row, tall enough that a page's proportions still read.
class SwatchGrid extends StatelessWidget {
  final List<Widget> children;

  const SwatchGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 0.66,
      children: children,
    );
  }
}

/// One choice in either picker: the chosen paper, the chosen ornament, and a
/// stand-in for the text — the page in miniature, whichever of the two is
/// being picked.
class Swatch extends StatelessWidget {
  final String label;
  final bool active;
  final MushafPalette palette;
  final MushafFrame frame;
  final VoidCallback onTap;

  const Swatch({
    super.key,
    required this.label,
    required this.active,
    required this.palette,
    required this.frame,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: palette.paper,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: active ? AppColors.gold : Colors.transparent,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: MushafFrameBox(
                frame: frame,
                color: palette.ink,
                child: PreviewLines(color: palette.onPaperMuted),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? AppColors.gold : AppColors.textMuted,
              fontSize: 10,
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Stand-in for the text, so a swatch shows how much room the ornament leaves
/// the page.
class PreviewLines extends StatelessWidget {
  const PreviewLines({super.key, this.color = const Color(0xFF6B6250)});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 4; i++)
            Container(
              height: 2,
              margin: const EdgeInsets.symmetric(vertical: 2),
              width: i.isEven ? double.infinity : null,
              constraints: const BoxConstraints(minWidth: 14),
              color: color,
            ),
        ],
      ),
    );
  }
}
