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
    debugPrint('Filling item with fill: ${item.fill}, path count: ${geometry.closedPaths.length}');

    // Fill paths
    final Paint fillPaint = Paint()
      ..color = item.fill ?? Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final Path path in geometry.closedPaths) {
      final bounds = path.getBounds();
      if (bounds.isEmpty || !bounds.isFinite) {
        debugPrint('Skipping invalid path with bounds: $bounds');
        continue;
      }
      path.fillType = geometry.fillRule == FillRule.evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;
      debugPrint('Drawing path with bounds: $bounds, fill: ${fillPaint.color}');
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
    final SvgGeometry geometry = item.geometry;
    debugPrint('Hit testing at position: $position, path count: ${geometry.closedPaths.length}');

    for (final Path path in geometry.closedPaths) {
      final bounds = path.getBounds();
      if (bounds.isEmpty || !bounds.isFinite) {
        debugPrint('Skipping hit test on invalid path with bounds: $bounds');
        continue;
      }
      if (_pathContainsPoint(path, position)) {
        debugPrint('Hit detected on path with bounds: ${path.getBounds()}');
        onTap?.call();
        return true;
      }
    }
    return false;
  }

  static bool _pathContainsPoint(Path path, Offset point) {
    return path.contains(point);
  }
}