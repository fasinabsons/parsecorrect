import 'package:flutter/material.dart';
import 'svg_geometry_parser.dart';
import 'svg_enums.dart';

class ColorFillingManager {
  static void fillColor({
    required Canvas canvas,
    required EnhancedPathSvgItem item,
    bool drawOutline = true,
    Color outlineColor = const Color(0xFF444444),
    double outlineWidth = 0.85,
  }) {
    final SvgGeometry geometry = item.geometry;
    debugPrint('Filling item with fill: ${item.fill} (value: ${item.fill?.toARGB32().toRadixString(16) ?? 'null'}), path count: ${geometry.closedPaths.length}');

    // Fill paths
    if (item.fill == null) return; // Skip if no fill
final Paint fillPaint = Paint()
  ..color = item.fill!
  ..style = PaintingStyle.fill
  ..isAntiAlias = true;

    for (final Path path in geometry.closedPaths) {
      final bounds = path.getBounds();
      if (bounds.isEmpty || !bounds.isFinite || bounds.width <= 0 || bounds.height <= 0) {
        debugPrint('Skipping invalid path with bounds: $bounds');
        continue;
      }
      path.fillType = geometry.fillRule == FillRule.evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
      debugPrint('Drawing path with bounds: $bounds, fill: ${fillPaint.color} (value: ${fillPaint.color.toARGB32().toRadixString(16)})');
      canvas.drawPath(path, fillPaint);
    }

    // Draw outlines
    if (drawOutline && geometry.lineGeometry != null) {
      final Paint edgePaint = Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = outlineWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true;

      final lines = geometry.lineGeometry!.lines;
      debugPrint('Drawing ${lines.length} outline segments');
      for (final line in lines) {
        canvas.drawLine(line.start, line.end, edgePaint);
      }
    }
  }

  static bool hitTest({
  required EnhancedPathSvgItem item,
  required Offset position,
  required VoidCallback? onTap,
}) {
  for (final path in item.geometry.closedPaths) {
    if (path.contains(position)) {
      onTap?.call();
      return true;
    }
  }
  return false;
}

}