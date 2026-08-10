import 'dart:io';
import 'package:flutter/material.dart';
import '../data/ayah_boxes.dart';

/// The printed page with an ayah-selection layer over it.
///
/// The published images are a fixed width but vary in height, so rather than
/// assuming a size this reads the intrinsic dimensions off the decoded image
/// and derives the drawn rectangle from them. Tap points are mapped back into
/// that space before hit testing, which keeps selection accurate at any screen
/// size and at any zoom level.
class MushafPageImage extends StatefulWidget {
  final File file;
  final List<AyahBoxes> boxes;
  final AyahBoxes? selected;
  final ValueChanged<AyahBoxes?> onAyahTapped;

  /// Called when the tap misses every ayah, e.g. a margin or the border.
  final VoidCallback onBackgroundTapped;

  const MushafPageImage({
    super.key,
    required this.file,
    required this.boxes,
    required this.selected,
    required this.onAyahTapped,
    required this.onBackgroundTapped,
  });

  @override
  State<MushafPageImage> createState() => _MushafPageImageState();
}

class _MushafPageImageState extends State<MushafPageImage> {
  late FileImage _provider;
  ImageStreamListener? _listener;
  ImageStream? _stream;
  Size? _intrinsic;

  @override
  void initState() {
    super.initState();
    _provider = FileImage(widget.file);
    _resolve();
  }

  @override
  void didUpdateWidget(MushafPageImage old) {
    super.didUpdateWidget(old);
    if (old.file.path != widget.file.path) {
      _dropStream();
      _provider = FileImage(widget.file);
      _intrinsic = null;
      _resolve();
    }
  }

  @override
  void dispose() {
    _dropStream();
    super.dispose();
  }

  void _resolve() {
    _stream = _provider.resolve(const ImageConfiguration());
    _listener = ImageStreamListener((info, _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (mounted && _intrinsic != size) setState(() => _intrinsic = size);
    });
    _stream!.addListener(_listener!);
  }

  void _dropStream() {
    if (_stream != null && _listener != null) {
      _stream!.removeListener(_listener!);
    }
    _stream = null;
    _listener = null;
  }

  /// Where the image actually lands inside [box] under BoxFit.contain.
  Rect _drawnRect(Size box, Size image) {
    final scale =
        (box.width / image.width).clamp(0.0, box.height / image.height);
    final width = image.width * scale;
    final height = image.height * scale;
    return Rect.fromLTWH(
      (box.width - width) / 2,
      (box.height - height) / 2,
      width,
      height,
    );
  }

  void _handleTap(TapUpDetails details, Size box) {
    final image = _intrinsic;
    if (image == null) return;

    final drawn = _drawnRect(box, image);
    final local = details.localPosition;
    if (!drawn.contains(local)) {
      widget.onBackgroundTapped();
      return;
    }

    // Back into source-image pixels, then into the reference space the boxes
    // were recorded in.
    final scale = image.width / drawn.width;
    final inImage = Offset(
      (local.dx - drawn.left) * scale,
      (local.dy - drawn.top) * scale,
    );
    final toReference = AyahBoxService.referenceWidth / image.width;
    final point = inImage * toReference;

    final hit = AyahBoxService.hitTest(widget.boxes, point);
    if (hit == null) {
      widget.onBackgroundTapped();
    } else {
      widget.onAyahTapped(hit);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final box = Size(constraints.maxWidth, constraints.maxHeight);
        final image = _intrinsic;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => _handleTap(d, box),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image(image: _provider, fit: BoxFit.contain),
              if (image != null && widget.selected != null)
                CustomPaint(
                  painter: _HighlightPainter(
                    rects: widget.selected!.rects,
                    drawn: _drawnRect(box, image),
                    referenceWidth: AyahBoxService.referenceWidth,
                    imageWidth: image.width,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Lays a soft wash over the selected ayah — visible enough to locate it,
/// light enough to read straight through.
class _HighlightPainter extends CustomPainter {
  final List<Rect> rects;
  final Rect drawn;
  final double referenceWidth;
  final double imageWidth;

  const _HighlightPainter({
    required this.rects,
    required this.drawn,
    required this.referenceWidth,
    required this.imageWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = drawn.width / referenceWidth;
    final fill = Paint()..color = const Color(0x33C9A227);
    final edge = Paint()
      ..color = const Color(0x66B8860B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final r in rects) {
      final mapped = Rect.fromLTRB(
        drawn.left + r.left * scale,
        drawn.top + r.top * scale,
        drawn.left + r.right * scale,
        drawn.top + r.bottom * scale,
      ).inflate(1.5);
      final rounded = RRect.fromRectAndRadius(mapped, const Radius.circular(3));
      canvas.drawRRect(rounded, fill);
      canvas.drawRRect(rounded, edge);
    }
  }

  @override
  bool shouldRepaint(_HighlightPainter old) =>
      old.rects != rects || old.drawn != drawn;
}
