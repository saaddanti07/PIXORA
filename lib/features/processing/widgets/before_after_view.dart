import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pixora/app/theme/app_spacing.dart';

/// Original-versus-result comparison with a draggable divider.
///
/// Both images are decoded at a bounded width ([cacheWidth]) because a 2048 px
/// result held at full resolution next to the original is exactly how a low-RAM
/// phone runs out of memory while merely *showing* a result.
class BeforeAfterView extends StatefulWidget {
  const BeforeAfterView({
    required this.beforePath,
    required this.afterPath,
    required this.aspectRatio,
    required this.beforeLabel,
    required this.afterLabel,
    this.cacheWidth = 1200,
    this.imageBuilder,
    super.key,
  }) : assert(
          beforePath != afterPath,
          'BeforeAfterView requires distinct original and result paths.',
        );

  final String beforePath;
  final String afterPath;
  final double aspectRatio;
  final String beforeLabel;
  final String afterLabel;
  final int cacheWidth;
  final Widget Function(BuildContext context, String path, BoxFit fit)? imageBuilder;

  @override
  State<BeforeAfterView> createState() => _BeforeAfterViewState();
}

class _BeforeAfterViewState extends State<BeforeAfterView> {
  double _position = 0.5;

  void _update(double dx, double width) {
    if (width <= 0) {
      return;
    }
    setState(() => _position = (dx / width).clamp(0.02, 0.98));
  }

  Widget _image(String path, BoxFit fit) => widget.imageBuilder?.call(context, path, fit) ?? Image.file(
        File(path),
        fit: fit,
        key: ValueKey<String>(path),
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: false,
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) =>
            const ColoredBox(
          color: Color(0xFF1B1B1F),
          child: Center(child: Icon(Icons.broken_image_outlined)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: AspectRatio(
        aspectRatio: widget.aspectRatio,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            final double height = constraints.maxHeight;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (TapDownDetails details) =>
                  _update(details.localPosition.dx, width),
              onHorizontalDragUpdate: (DragUpdateDetails details) =>
                  _update(details.localPosition.dx, width),
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  _image(widget.afterPath, BoxFit.cover),
                  ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: _position,
                      child: SizedBox(
                        width: width,
                        height: height,
                        child: _image(widget.beforePath, BoxFit.cover),
                      ),
                    ),
                  ),
                  Positioned(
                    left: width * _position - 1,
                    top: 0,
                    bottom: 0,
                    child: Container(width: 2, color: Colors.white70),
                  ),
                  Positioned(
                    left: width * _position - 18,
                    top: height / 2 - 18,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.drag_indicator_rounded,
                        size: 20,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: _chip(widget.beforeLabel, textTheme),
                  ),
                  Positioned(
                    right: AppSpacing.sm,
                    top: AppSpacing.sm,
                    child: _chip(widget.afterLabel, textTheme),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _chip(String label, TextTheme textTheme) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: textTheme.labelSmall?.copyWith(color: Colors.white),
        ),
      );
}
