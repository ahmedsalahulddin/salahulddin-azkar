import 'package:flutter/material.dart';

import '../constants/theme.dart';
import '../l10n/strings.dart';

/// One stop on an on-screen tour: the widget to light up (by its key) and
/// what to say about it.
class CoachStep {
  final GlobalKey target;
  final String title;
  final String body;

  const CoachStep({
    required this.target,
    required this.title,
    required this.body,
  });
}

/// Walks the reader through [steps] on the live screen: everything dims
/// except the widget being explained, with a short note beside it and
/// Next / Skip. Steps whose widget isn't on screen are passed over.
Future<void> showCoachMarks(
  BuildContext context,
  List<CoachStep> steps, {
  required TextDirection direction,
}) async {
  final visible = [
    for (final s in steps)
      if (s.target.currentContext?.findRenderObject() is RenderBox) s,
  ];
  if (visible.isEmpty) return;
  await Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) =>
          _CoachOverlay(steps: visible, direction: direction),
      transitionsBuilder: (_, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _CoachOverlay extends StatefulWidget {
  final List<CoachStep> steps;
  final TextDirection direction;

  const _CoachOverlay({required this.steps, required this.direction});

  @override
  State<_CoachOverlay> createState() => _CoachOverlayState();
}

class _CoachOverlayState extends State<_CoachOverlay> {
  int _i = 0;

  Rect? _rectOf(CoachStep s) {
    final box = s.target.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return (topLeft & box.size).inflate(6);
  }

  void _next() {
    if (_i + 1 >= widget.steps.length) {
      Navigator.pop(context);
    } else {
      setState(() => _i++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_i];
    final rect = _rectOf(step) ?? Rect.zero;
    final size = MediaQuery.of(context).size;
    final below = rect.center.dy < size.height * 0.55;
    const margin = 16.0;

    return Directionality(
      textDirection: widget.direction,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: _next,
          behavior: HitTestBehavior.opaque,
          child: Stack(
            children: [
              Positioned.fill(
                child: TweenAnimationBuilder<Rect?>(
                  tween: RectTween(end: rect),
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOutCubic,
                  builder: (_, r, _) =>
                      CustomPaint(painter: _HolePainter(r ?? rect)),
                ),
              ),
              Positioned(
                left: margin,
                right: margin,
                top: below ? rect.bottom + 14 : null,
                bottom: below ? null : size.height - rect.top + 14,
                child: _bubble(step),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bubble(CoachStep step) {
    final last = _i + 1 == widget.steps.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.blackCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  step.title,
                  style: const TextStyle(
                    color: AppColors.gold,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${_i + 1} ${t('guide.of')} ${widget.steps.length}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            step.body,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (!last)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    t('guide.skip'),
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              const Spacer(),
              FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.gold,
                  foregroundColor: AppColors.black,
                ),
                child: Text(last ? t('guide.done') : t('guide.next')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The dimmed screen with a rounded window cut over the widget in focus,
/// outlined in gold.
class _HolePainter extends CustomPainter {
  final Rect hole;
  _HolePainter(this.hole);

  @override
  void paint(Canvas canvas, Size size) {
    final rounded = RRect.fromRectAndRadius(hole, const Radius.circular(14));
    final dim = Path.combine(
      PathOperation.difference,
      Path()..addRect(Offset.zero & size),
      Path()..addRRect(rounded),
    );
    canvas.drawPath(dim, Paint()..color = Colors.black.withValues(alpha: 0.78));
    canvas.drawRRect(
      rounded,
      Paint()
        ..color = AppColors.gold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  @override
  bool shouldRepaint(_HolePainter old) => old.hole != hole;
}
