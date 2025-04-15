import 'package:flutter/material.dart';
import '../utils/svg_geometry_parser.dart';
import '../utils/color_filling.dart';
import 'dart:math';

class SvgPainter extends CustomPainter {
  final EnhancedPathSvgItem item;
  final bool drawEdges;
  final Rect? parentBounds;

  SvgPainter(this.item, {this.drawEdges = true, this.parentBounds});

  @override
  void paint(Canvas canvas, Size size) {
    if (size == Size.zero) {
      debugPrint('Zero size, skipping paint');
      return;
    }

    final path = item.path;
    final pathBounds = path.getBounds();
    if (pathBounds.isEmpty || !pathBounds.isFinite) {
      debugPrint('Invalid path bounds: $pathBounds');
      return;
    }

    final effectiveBounds = parentBounds != null && parentBounds!.isFinite && !parentBounds!.isEmpty
        ? parentBounds!
        : pathBounds;

    if (effectiveBounds.width <= 0 || effectiveBounds.height <= 0) {
      debugPrint('Invalid effective bounds: $effectiveBounds');
      return;
    }

    final scaleX = size.width / effectiveBounds.width;
    final scaleY = size.height / effectiveBounds.height;
    final scale = min(scaleX, scaleY);
    final offset = Offset(
      (size.width - effectiveBounds.width * scale) / 2 - effectiveBounds.left * scale,
      (size.height - effectiveBounds.height * scale) / 2 - effectiveBounds.top * scale,
    );

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    ColorFillingManager.fillColor(
      canvas: canvas,
      item: item,
      drawOutline: drawEdges,
      outlineColor: Colors.black,
      outlineWidth: 1.0 / max(scale, 0.01),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SvgPainter oldDelegate) {
    return item.fill?.toARGB32() != oldDelegate.item.fill?.toARGB32() ||
        item.geometry != oldDelegate.item.geometry ||
        drawEdges != oldDelegate.drawEdges ||
        parentBounds != oldDelegate.parentBounds;
  }
}

class SvgPainterImage extends StatelessWidget {
  const SvgPainterImage({
    super.key,
    required this.item,
    this.onTap,
    this.drawEdges = true,
    this.parentBounds,
  });

  final EnhancedPathSvgItem item;
  final VoidCallback? onTap;
  final bool drawEdges;
  final Rect? parentBounds;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return GestureDetector(
          onTapDown: (details) {
            final position = details.localPosition;
            final path = item.path;
            final pathBounds = path.getBounds();
            if (pathBounds.isEmpty || !pathBounds.isFinite) {
              debugPrint('Invalid path bounds for tap: $pathBounds');
              return;
            }

            final effectiveBounds = parentBounds != null && parentBounds!.isFinite && !parentBounds!.isEmpty
                ? parentBounds!
                : pathBounds;

            if (effectiveBounds.width <= 0 || effectiveBounds.height <= 0) {
              debugPrint('Invalid effective bounds for tap: $effectiveBounds');
              return;
            }

            final scaleX = size.width / effectiveBounds.width;
            final scaleY = size.height / effectiveBounds.height;
            final scale = min(scaleX, scaleY);
            final offset = Offset(
              (size.width - effectiveBounds.width * scale) / 2 - effectiveBounds.left * scale,
              (size.height - effectiveBounds.height * scale) / 2 - effectiveBounds.top * scale,
            );

            final transformedPosition = (position - offset) / scale;
            final wasHit = item.path.contains(transformedPosition);
if (wasHit) {
  onTap?.call();
  debugPrint('Tapped item with bounds: $pathBounds, effective: $effectiveBounds');
} else {
  debugPrint('No hit detected for tap at position: $transformedPosition');
}
          },
          child: CustomPaint(
            size: size,
            painter: SvgPainter(item, drawEdges: drawEdges, parentBounds: parentBounds),
          ),
        );
      },
    );
  }
}