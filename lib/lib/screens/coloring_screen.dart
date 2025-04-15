import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/coloring_page.dart';
import '../utils/svg_parser.dart';
import '../utils/svg_geometry_parser.dart';
import '../widgets/svg_painter.dart';
import '../widgets/color_palette.dart';

class ColoringScreen extends StatefulWidget {
  final ColoringPage page;

  const ColoringScreen({super.key, required this.page});

  @override
  State<ColoringScreen> createState() => _ColoringScreenState();
}

class _ColoringScreenState extends State<ColoringScreen> {
  Size? _size;
  List<EnhancedPathSvgItem> _items = [];
  Color selectedColor = Colors.red;
  String? _errorMessage;
  Rect? _vectorBounds;
  bool _isPaletteVisible = false;

  @override
  void initState() {
    super.initState();
    debugPrint('Initializing ColoringScreen for page: ${widget.page.svgPath}');
    _loadSavedColors();
    _init();
  }

  Future<void> _init() async {
    try {
      final VectorImage vectorImage = await getVectorImageFromAsset(widget.page.svgPath);
      final enhancedItems = await enhanceVectorImage(vectorImage);
      final bounds = vectorImage.bounds;

      setState(() {
        _size = bounds.isFinite && !bounds.isEmpty
            ? Size(bounds.width, bounds.height)
            : vectorImage.size ?? const Size(300, 400);
        _vectorBounds = bounds.isFinite ? bounds : null;
        _items = enhancedItems;
      });

      _applySavedColors();
    } catch (e, stackTrace) {
      debugPrint('Error initializing coloring page: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _size = const Size(300, 400);
        _errorMessage = 'Failed to load SVG: $e';
      });
    }
  }

  Future<void> _loadSavedColors() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedColors = prefs.getStringList('coloring_${widget.page.id}');
    if (savedColors != null) {
      debugPrint('Loaded saved colors: $savedColors');
    }
  }

  Future<void> _applySavedColors() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? savedColors = prefs.getStringList('coloring_${widget.page.id}');
    if (savedColors != null && savedColors.length == _items.length) {
      setState(() {
        for (int i = 0; i < _items.length; i++) {
          final colorStr = savedColors[i];
          if (colorStr.isNotEmpty) {
            try {
              final color = Color(int.parse(colorStr, radix: 16));
              if (color.toARGB32() != 0xFF010101) {
                _items[i] = _items[i].copyWith(
                  originalItem: _items[i].originalItem.copyWith(fill: color),
                );
              }
            } catch (_) {}
          }
        }
      });
    }
  }

  Future<void> _saveColors() async {
    final prefs = await SharedPreferences.getInstance();
    final colors = _items.map((item) {
      final color = item.fill;
      return color != null && color.toARGB32() != 0xFF010101
          ? color.toARGB32().toRadixString(16).padLeft(8, '0')
          : '';
    }).toList();
    await prefs.setStringList('coloring_${widget.page.id}', colors);
  }

  void _onTap(int index) {
    final path = _items[index].path;
    final bounds = path.getBounds();
    if (bounds.isEmpty || !bounds.isFinite || bounds.width <= 0 || bounds.height <= 0) {
      return;
    }

    setState(() {
      _items = List.from(_items);
      _items[index] = _items[index].copyWith(
        originalItem: _items[index].originalItem.copyWith(fill: selectedColor),
      );
      if (_isPaletteVisible) {
        _isPaletteVisible = false;
      }
    });

    _saveColors();
  }

  void _togglePalette() {
    setState(() {
      _isPaletteVisible = !_isPaletteVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(widget.page.category),
          backgroundColor: Colors.pinkAccent,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 50),
              const SizedBox(height: 10),
              Text(_errorMessage!, style: const TextStyle(fontSize: 16, color: Colors.red)),
            ],
          ),
        ),
      );
    }

    if (_size == null || _items.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.page.category),
        backgroundColor: Colors.pinkAccent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: _size!.width,
                    height: _size!.height,
                    child: Stack(
                      children: _items.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        return SvgPainterImage(
                          item: item,
                          onTap: () => _onTap(index),
                          drawEdges: true,
                          parentBounds: _vectorBounds,
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: FloatingActionButton(
                  onPressed: _togglePalette,
                  backgroundColor: Colors.pinkAccent,
                  child: const Icon(Icons.palette),
                ),
              ),
            ],
          ),
          if (_isPaletteVisible)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ColorPalette(
                  selectedColor: selectedColor,
                  onColorSelected: (color) {
                    setState(() {
                      selectedColor = color;
                      _isPaletteVisible = false;
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
