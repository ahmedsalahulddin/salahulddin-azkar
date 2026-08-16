import 'package:flutter/material.dart';

/// How tall the two reading bars actually are.
///
/// The page has to be laid out to exactly clear them: the border sits on the
/// bottom edge of the top bar and on the top edge of the bottom bar, and the
/// ayat fill everything between. That cannot be done from constants — the bars
/// stand on the phone's own system bars, which differ by device, and their
/// rows grow with the reader's font scale. So the bars measure themselves and
/// the page reads what they report.
class MushafChrome {
  MushafChrome._();

  static final topHeight = ValueNotifier<double>(0);
  static final bottomHeight = ValueNotifier<double>(0);

  /// A first guess, so the page is close on the frame before the bars have
  /// been measured. Replaced by the real numbers on the first layout.
  static void seed(EdgeInsets viewPadding) {
    if (topHeight.value == 0) topHeight.value = viewPadding.top + 62;
    if (bottomHeight.value == 0) bottomHeight.value = viewPadding.bottom + 45;
  }

  @visibleForTesting
  static void debugSet({double? top, double? bottom}) {
    if (top != null) topHeight.value = top;
    if (bottom != null) bottomHeight.value = bottom;
  }
}

/// Wraps a bar and reports its height into [into].
///
/// Measured after the frame rather than computed from the paddings inside it:
/// a sum written by hand goes stale the moment anything in the bar changes,
/// and the page laid out against it would be wrong with nothing to show why.
class MeasuredBar extends StatefulWidget {
  final ValueNotifier<double> into;
  final Widget child;

  const MeasuredBar({super.key, required this.into, required this.child});

  @override
  State<MeasuredBar> createState() => _MeasuredBarState();
}

class _MeasuredBarState extends State<MeasuredBar> {
  @override
  void initState() {
    super.initState();
    _report();
  }

  @override
  void didUpdateWidget(MeasuredBar old) {
    super.didUpdateWidget(old);
    _report();
  }

  void _report() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final height = context.size?.height;
      if (height != null && (widget.into.value - height).abs() > 0.5) {
        widget.into.value = height;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    _report();
    return widget.child;
  }
}
