// utils/history_manager.dart
import '../utils/svg_geometry_parser.dart'; // Import to access EnhancedPathSvgItem
import 'dart:developer';

mixin HistoryManager<T> {
  List<T> _history = [];
  int _historyIndex = -1;

  void saveToHistory(T state) {
    // Create a deep copy of the state to avoid mutating previous states
    final T stateCopy = (state is List<EnhancedPathSvgItem>)
        ? List<EnhancedPathSvgItem>.from(state.map((item) => item.copyWith())) as T
        : state;

    if (_historyIndex < _history.length - 1) {
      _history = _history.sublist(0, _historyIndex + 1);
    }
    _history.add(stateCopy);
    _historyIndex++;
    log('Saved to history: $_historyIndex, total history: ${_history.length}');
  }

  T? undo() {
    if (_historyIndex > 0) {
      _historyIndex--;
      log('Undo to index: $_historyIndex');
      return _history[_historyIndex];
    }
    return null;
  }

  T? redo() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      log('Redo to index: $_historyIndex');
      return _history[_historyIndex];
    }
    return null;
  }

  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;
}