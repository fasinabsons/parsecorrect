import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_drawing/path_drawing.dart';
import 'package:xml/xml.dart';
import 'dart:math';
import 'svg_enums.dart';

class VectorImage {
  const VectorImage({required this.items, this.size});

  final List<PathSvgItem> items;
  final Size? size;

  Rect get bounds {
    if (items.isEmpty) {
      debugPrint('No items in VectorImage, returning zero bounds');
      return Rect.zero;
    }
    Rect bounds = Rect.fromLTRB(
      double.infinity,
      double.infinity,
      double.negativeInfinity,
      double.negativeInfinity,
    );
    for (final item in items) {
      final itemBounds = item.path.getBounds();
      if (!itemBounds.isEmpty && itemBounds.isFinite) {
        bounds = Rect.fromLTRB(
          min(bounds.left, itemBounds.left),
          min(bounds.top, itemBounds.top),
          max(bounds.right, itemBounds.right),
          max(bounds.bottom, itemBounds.bottom),
        );
      } else {
        debugPrint('Skipping invalid path bounds: $itemBounds');
      }
    }
    // Ensure non-zero, finite bounds
    if (bounds.isEmpty || !bounds.isFinite || bounds.width <= 0 || bounds.height <= 0) {
      debugPrint('Invalid SVG bounds, using default: $bounds');
      return const Rect.fromLTWH(0, 0, 300, 400);
    }
    return bounds;
  }
}

class PathSvgItem {
  const PathSvgItem({
    required this.path,
    this.fill,
    this.fillRule = FillRule.nonZero,
  });

  final Path path;
  final Color? fill;
  final FillRule fillRule;

  PathSvgItem copyWith({
    Path? path,
    Color? fill,
    FillRule? fillRule,
  }) {
    return PathSvgItem(
      path: path ?? this.path,
      fill: fill ?? this.fill,
      fillRule: fillRule ?? this.fillRule,
    );
  }
}

Future<VectorImage> getVectorImageFromAsset(String assetPath) async {
  debugPrint('Loading SVG from asset: $assetPath');
  try {
    final String svgData = await rootBundle.loadString(assetPath);
    return getVectorImageFromStringXml(svgData);
  } catch (e) {
    debugPrint('Error loading SVG asset: $e');
    rethrow;
  }
}

VectorImage getVectorImageFromStringXml(String svgData) {
  debugPrint('Parsing SVG XML data');
  final List<PathSvgItem> items = [];

  try {
    final XmlDocument document = XmlDocument.parse(svgData);
    final XmlElement? svgElement = document.findAllElements('svg').firstOrNull;
    if (svgElement == null) throw Exception('No <svg> element found.');

    Size? size = _parseSvgSize(svgElement);

    final Map<String, XmlElement> defs = {};
    for (final def in document.findAllElements('defs')) {
      for (final child in def.findElements('*')) {
        final id = child.getAttribute('id');
        if (id != null) defs[id] = child;
      }
    }

    void extractShapes(XmlElement parent, Matrix4 inheritedTransform) {
      for (final element in parent.children.whereType<XmlElement>()) {
        final Matrix4 transform = inheritedTransform.clone()
          ..multiply(_getTransformFromElement(element));

        final tag = element.name.local;
        if (tag == 'g') {
          extractShapes(element, transform);
        } else if (tag == 'use') {
          final href = element.getAttribute('xlink:href') ?? element.getAttribute('href');
          if (href != null && defs.containsKey(href.replaceFirst('#', ''))) {
            final referenced = defs[href.replaceFirst('#', '')]!;
            final Matrix4 useTransform = transform.clone()
              ..multiply(_getTransformFromElement(referenced));
            extractShapes(referenced, useTransform);
          }
        } else {
          final parsed = _parseElementAsPathSvgItem(element, transform);
          if (parsed != null) items.add(parsed);
        }
      }
    }

    extractShapes(svgElement, Matrix4.identity());

    debugPrint('Parsed ${items.length} drawable items');
    return VectorImage(items: items, size: size ?? const Size(300, 400));
  } catch (e, stackTrace) {
    debugPrint('Error parsing SVG: $e');
    debugPrint('Stack trace: $stackTrace');
    return VectorImage(items: [], size: const Size(300, 400));
  }
}

Size? _parseSvgSize(XmlElement svgElement) {
  try {
    String? width = svgElement.getAttribute('width');
    String? height = svgElement.getAttribute('height');
    if (width != null && height != null) {
      width = width.replaceAll(RegExp(r'[^0-9.]'), '');
      height = height.replaceAll(RegExp(r'[^0-9.]'), '');
      final w = double.tryParse(width) ?? 0;
      final h = double.tryParse(height) ?? 0;
      if (w > 0 && h > 0) return Size(w, h);
    }
    final viewBox = svgElement.getAttribute('viewBox');
    if (viewBox != null) {
      final parts = viewBox.split(RegExp(r'[ ,]+')).map(double.tryParse).toList();
      if (parts.length == 4 && parts.every((p) => p != null)) {
        return Size(parts[2]!, parts[3]!);
      }
    }
  } catch (e) {
    debugPrint('Error parsing size: $e');
  }
  return null;
}

PathSvgItem? _parseElementAsPathSvgItem(XmlElement element, Matrix4 transform) {
  final tag = element.name.local;
  Path? path;

  try {
    if (tag == 'path') {
      final d = element.getAttribute('d');
      if (d != null && d.trim().isNotEmpty) {
        path = parseSvgPathData(d);
      }
    } else if (tag == 'rect') {
      final x = double.tryParse(element.getAttribute('x') ?? '0') ?? 0;
      final y = double.tryParse(element.getAttribute('y') ?? '0') ?? 0;
      final w = double.tryParse(element.getAttribute('width') ?? '0') ?? 0;
      final h = double.tryParse(element.getAttribute('height') ?? '0') ?? 0;
      if (w > 0 && h > 0) {
        path = Path()..addRect(Rect.fromLTWH(x, y, w, h));
      }
    } else if (tag == 'circle') {
      final cx = double.tryParse(element.getAttribute('cx') ?? '0') ?? 0;
      final cy = double.tryParse(element.getAttribute('cy') ?? '0') ?? 0;
      final r = double.tryParse(element.getAttribute('r') ?? '0') ?? 0;
      if (r > 0) {
        path = Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
      }
    } else if (tag == 'ellipse') {
      final cx = double.tryParse(element.getAttribute('cx') ?? '0') ?? 0;
      final cy = double.tryParse(element.getAttribute('cy') ?? '0') ?? 0;
      final rx = double.tryParse(element.getAttribute('rx') ?? '0') ?? 0;
      final ry = double.tryParse(element.getAttribute('ry') ?? '0') ?? 0;
      if (rx > 0 && ry > 0) {
        path = Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));
      }
    } else if (tag == 'polygon') {
      final pts = element.getAttribute('points');
      if (pts != null && pts.trim().isNotEmpty) {
        path = _pointsToPath(pts, close: true);
      }
    } else if (tag == 'polyline') {
      final pts = element.getAttribute('points');
      if (pts != null && pts.trim().isNotEmpty) {
        path = _pointsToPath(pts, close: false);
      }
    } else if (tag == 'line') {
      final x1 = element.getAttribute('x1');
      final y1 = element.getAttribute('y1');
      final x2 = element.getAttribute('x2');
      final y2 = element.getAttribute('y2');
      if ([x1, y1, x2, y2].every((e) => e != null)) {
        path = Path()
          ..moveTo(double.tryParse(x1!) ?? 0, double.tryParse(y1!) ?? 0)
          ..lineTo(double.tryParse(x2!) ?? 0, double.tryParse(y2!) ?? 0);
      }
    }

    if (path == null || path.getBounds().isEmpty) {
      debugPrint('Skipping empty or invalid path for tag: $tag');
      return null;
    }

    path = path.transform(transform.storage);
    final fillRuleAttr = element.getAttribute('fill-rule');
    final FillRule rule = fillRuleAttr == 'evenodd' ? FillRule.evenOdd : FillRule.nonZero;
    path.fillType = rule == FillRule.evenOdd ? PathFillType.evenOdd : PathFillType.nonZero;

    return _processElement(element, path, rule);
  } catch (e, stackTrace) {
    debugPrint('Error parsing <$tag>: $e');
    debugPrint('Stack trace: $stackTrace');
    return null;
  }
}

Matrix4 _getTransformFromElement(XmlElement element) {
  final transform = element.getAttribute('transform');
  if (transform == null || transform.trim().isEmpty) return Matrix4.identity();
  final matrix = Matrix4.identity();

  try {
    // Normalize transform string: handle multiple spaces, commas
    final cleanedTransform = transform.replaceAll(RegExp(r'\s+'), ' ').trim();
    final parts = cleanedTransform.split(')').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

    for (var t in parts) {
      if (t.contains('translate')) {
        final m = RegExp(r'translate\(([^,\s]+)\s*,?\s*([^,\)]+)?\)').firstMatch(t);
        if (m != null) {
          final x = double.tryParse(m.group(1)?.trim() ?? '0') ?? 0;
          final y = double.tryParse(m.group(2)?.trim() ?? '0') ?? 0;
          matrix.translate(x, y);
        }
      } else if (t.contains('scale')) {
        final m = RegExp(r'scale\(([^,\s]+)\s*,?\s*([^,\)]+)?\)').firstMatch(t);
        if (m != null) {
          final sx = double.tryParse(m.group(1)?.trim() ?? '1') ?? 1;
          final sy = m.group(2) != null ? double.tryParse(m.group(2)!.trim()) ?? sx : sx;
          matrix.scale(sx, sy);
        }
      } else if (t.contains('rotate')) {
        final m = RegExp(r'rotate\(([^,\s]+)\s*(?:,([^,\s]+)\s*,([^,\s]+))?\)').firstMatch(t);
        if (m != null) {
          final angle = (double.tryParse(m.group(1)?.trim() ?? '0') ?? 0) * pi / 180;
          if (m.group(2) != null && m.group(3) != null) {
            final cx = double.tryParse(m.group(2)?.trim() ?? '0') ?? 0;
            final cy = double.tryParse(m.group(3)?.trim() ?? '0') ?? 0;
            matrix.translate(cx, cy);
            matrix.rotateZ(angle);
            matrix.translate(-cx, -cy);
          } else {
            matrix.rotateZ(angle);
          }
        }
      } else if (t.contains('matrix')) {
        final m = RegExp(r'matrix\(([^,\s]+)\s*,([^,\s]+)\s*,([^,\s]+)\s*,([^,\s]+)\s*,([^,\s]+)\s*,([^,\s]+)\)').firstMatch(t);
        if (m != null) {
          final a = double.tryParse(m.group(1)?.trim() ?? '1') ?? 1;
          final b = double.tryParse(m.group(2)?.trim() ?? '0') ?? 0;
          final c = double.tryParse(m.group(3)?.trim() ?? '0') ?? 0;
          final d = double.tryParse(m.group(4)?.trim() ?? '1') ?? 1;
          final e = double.tryParse(m.group(5)?.trim() ?? '0') ?? 0;
          final f = double.tryParse(m.group(6)?.trim() ?? '0') ?? 0;
          matrix.setValues(a, b, 0, 0, c, d, 0, 0, 0, 0, 1, 0, e, f, 0, 1);
        }
      }
    }
  } catch (e, stackTrace) {
    debugPrint('Error parsing transform: $transform, error: $e');
    debugPrint('Stack trace: $stackTrace');
  }
  return matrix;
}

Path _pointsToPath(String points, {bool close = true}) {
  final path = Path();
  try {
    final coords = points.trim().split(RegExp(r'[\s,]+')).where((e) => e.isNotEmpty).toList();
    if (coords.length < 2) return path;
    for (int i = 0; i + 1 < coords.length; i += 2) {
      final x = double.tryParse(coords[i]) ?? 0;
      final y = double.tryParse(coords[i + 1]) ?? 0;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    if (close && coords.length >= 4) path.close();
  } catch (e, stackTrace) {
    debugPrint('Error parsing points: $points, error: $e');
    debugPrint('Stack trace: $stackTrace');
  }
  return path;
}

PathSvgItem _processElement(XmlElement element, Path path, FillRule rule) {
  final String? fillAttr = element.getAttribute('fill');
  final String? style = element.getAttribute('style');
  String? colorString = fillAttr;

  if (style != null) {
    final match = RegExp(r'fill\s*:\s*([^;]+);?', caseSensitive: false).firstMatch(style);
    if (match != null) colorString = match.group(1)?.trim();
  }

  // Default to white for coloring app unless explicitly "none"
  final Color? fillColor = colorString == null && fillAttr != 'none' ? Colors.white : _getColorFromString(colorString);

  return PathSvgItem(
    path: path,
    fill: fillColor,
    fillRule: rule,
  );
}

Color? _getColorFromString(String? colorString) {
  if (colorString == null || colorString.trim().isEmpty || colorString.trim().toLowerCase() == 'none') {
    return null;
  }

  colorString = colorString.trim().toLowerCase();

  // SVG named colors (partial list; expand as needed)
  const namedColors = {
    'black': Colors.black,
    'white': Colors.white,
    'red': Colors.red,
    'green': Colors.green,
    'blue': Colors.blue,
    'yellow': Colors.yellow,
    'purple': Colors.purple,
    'cyan': Colors.cyan,
    'gray': Colors.grey,
    'aliceblue': Color(0xFFF0F8FF),
    'antiquewhite': Color(0xFFFAEBD7),
    'aqua': Color(0xFF00FFFF),
    'aquamarine': Color(0xFF7FFFD4),
    // Add more from SVG spec if needed
  };
  if (namedColors.containsKey(colorString)) {
    return namedColors[colorString];
  }

  // Handle hex colors
  if (colorString.startsWith('#')) {
    final hex = colorString.substring(1);
    try {
      if (hex.length == 3) {
        final fullHex = hex.split('').map((c) => '$c$c').join();
        return Color(int.parse('ff$fullHex', radix: 16));
      } else if (hex.length == 6) {
        return Color(int.parse('ff$hex', radix: 16));
      } else if (hex.length == 8) {
        return Color(int.parse(hex, radix: 16));
      }
    } catch (e) {
      debugPrint('Invalid hex color: $colorString');
    }
  }

  // Parse RGB components (integers or percentages)
  double parseComponent(String s) {
    s = s.trim();
    try {
      if (s.endsWith('%')) {
        return (double.parse(s.replaceAll('%', '')) / 100.0) * 255.0;
      }
      final value = double.parse(s);
      return value.clamp(0, 255);
    } catch (e) {
      debugPrint('Invalid component: $s');
      return 0;
    }
  }

  // Handle rgb(r,g,b)
  final rgbMatch = RegExp(r'rgb\(\s*(\d+%?)\s*,\s*(\d+%?)\s*,\s*(\d+%?)\s*\)').firstMatch(colorString);
  if (rgbMatch != null) {
    try {
      final r = parseComponent(rgbMatch.group(1)!);
      final g = parseComponent(rgbMatch.group(2)!);
      final b = parseComponent(rgbMatch.group(3)!);
      return Color.fromRGBO(r.toInt(), g.toInt(), b.toInt(), 1.0);
    } catch (e) {
      debugPrint('Invalid RGB color: $colorString');
    }
  }

  // Handle rgba(r,g,b,a)
  final rgbaMatch = RegExp(r'rgba\(\s*(\d+%?)\s*,\s*(\d+%?)\s*,\s*(\d+%?)\s*,\s*(\d*\.?\d*)\s*\)').firstMatch(colorString);
  if (rgbaMatch != null) {
    try {
      final r = parseComponent(rgbaMatch.group(1)!);
      final g = parseComponent(rgbaMatch.group(2)!);
      final b = parseComponent(rgbaMatch.group(3)!);
      final a = double.tryParse(rgbaMatch.group(4) ?? '1')?.clamp(0, 1) ?? 1.0;
      return Color.fromRGBO(r.toInt(), g.toInt(), b.toInt(), a.toDouble());
    } catch (e) {
      debugPrint('Invalid RGBA color: $colorString');
    }
  }

  debugPrint('Unrecognized color: $colorString');
  return null;
}