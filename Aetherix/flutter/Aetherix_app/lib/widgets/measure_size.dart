import 'package:flutter/material.dart';

/// Reports its own rendered size via [onChange] after each layout pass.
///
/// Used by the feed and archive pages so the article list can reserve
/// exactly the right amount of space for the floating app bar — without
/// this, the first card gets hidden under the bar on the first frame
/// because the bar's true height isn't known until after layout.
class MeasureSize extends StatefulWidget {
  const MeasureSize({
    super.key,
    required this.onChange,
    required this.child,
  });
  final ValueChanged<Size> onChange;
  final Widget child;

  @override
  State<MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        widget.onChange(box.size);
      }
    });
    return widget.child;
  }
}
