// utils/line_parser.dart
import 'dart:ui';

class LineSegment {
  final Offset start;
  final Offset end;

  LineSegment(this.start, this.end);
}

class LineGeometry {
  final List<LineSegment> lines;

  LineGeometry({required this.lines});
}

LineGeometry parseLines(Path path) {
  final List<LineSegment> lines = [];
  final PathMetrics metrics = path.computeMetrics();
  for (final PathMetric metric in metrics) {
    final double step = metric.length / 100; // Adaptive step based on path length
    Offset? lastPosition;
    for (double t = 0; t <= metric.length; t += step) {
      final Tangent? tangent = metric.getTangentForOffset(t);
      if (tangent != null) {
        final Offset currentPosition = tangent.position;
        if (lastPosition != null) {
          lines.add(LineSegment(lastPosition, currentPosition));
        }
        lastPosition = currentPosition;
      }
    }
  }
  return LineGeometry(lines: lines);
}