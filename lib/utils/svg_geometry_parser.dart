import 'dart:ui';
import 'svg_enums.dart';
import 'svg_parser.dart';
import 'line_parser.dart';

class SvgGeometry {
  final List<Path> closedPaths;
  final LineGeometry? lineGeometry;
  final FillRule fillRule;

  SvgGeometry({
    required this.closedPaths,
    this.lineGeometry,
    required this.fillRule,
  });
}

class EnhancedPathSvgItem {
  final PathSvgItem originalItem;
  final SvgGeometry geometry;

  EnhancedPathSvgItem({
    required this.originalItem,
    required this.geometry,
  });

  Path get path => originalItem.path;
  Color? get fill => originalItem.fill;

  EnhancedPathSvgItem copyWith({
    PathSvgItem? originalItem,
    SvgGeometry? geometry,
  }) {
    return EnhancedPathSvgItem(
      originalItem: originalItem ?? this.originalItem,
      geometry: geometry ?? this.geometry,
    );
  }
}

Future<List<EnhancedPathSvgItem>> enhanceVectorImage(VectorImage vectorImage) async {
  return vectorImage.items.map((item) {
    final lineGeometry = parseLines(item.path); // Compute line geometry
    return EnhancedPathSvgItem(
      originalItem: item,
      geometry: SvgGeometry(
        closedPaths: [item.path],
        lineGeometry: lineGeometry,
        fillRule: item.fillRule,
      ),
    );
  }).toList();
}