import 'package:atomic_flutter/src/core.dart';

/// Wraps an [Atom] with bounded undo/redo history.
///
/// Changes are recorded automatically via a listener. [canUndo] and [canRedo]
/// are exposed as atoms so widgets can reactively enable/disable buttons.
///
/// ```dart
/// final counter = Atom<int>(0);
/// final history = AtomHistory(counter, maxHistory: 50);
///
/// counter.set(1);
/// counter.set(2);
/// history.undo(); // → 1
/// history.redo(); // → 2
///
/// // Reactive undo button:
/// AtomBuilder(
///   atom: history.canUndo,
///   builder: (ctx, can, _) => ElevatedButton(
///     onPressed: can ? history.undo : null,
///     child: const Text('Undo'),
///   ),
/// );
///
/// history.dispose(); // stop tracking
/// ```
///
/// Call [dispose] when the history tracker is no longer needed to remove
/// the listener from the source atom.
class AtomHistory<T> {
  final Atom<T> _atom;

  final _RingBuffer<T> _undoStack;
  final List<T> _redoStack = [];

  bool _isApplying = false;

  /// Whether there is a previous state to restore.
  late final Atom<bool> canUndo;

  /// Whether there is a state to redo after an undo.
  late final Atom<bool> canRedo;

  AtomHistory(this._atom, {int maxHistory = 50})
      : _undoStack = _RingBuffer<T>(maxHistory) {
    canUndo = Atom<bool>(false, autoDispose: false);
    canRedo = Atom<bool>(false, autoDispose: false);

    // Record the initial state
    _undoStack.push(_atom.value);

    _atom.addListener(_onAtomChanged);
  }

  void _onAtomChanged(T newValue) {
    if (_isApplying) return;
    _undoStack.push(newValue);
    _redoStack.clear();
    _updateReactiveState();
  }

  /// Restore the previous value.
  void undo() {
    if (_undoStack.length <= 1) return;
    _redoStack.add(_undoStack.pop()!);
    _apply(_undoStack.peek()!);
  }

  /// Re-apply a value that was undone.
  void redo() {
    if (_redoStack.isEmpty) return;
    final next = _redoStack.removeLast();
    _undoStack.push(next);
    _apply(next);
  }

  /// Clear all undo/redo history.
  void clear() {
    _undoStack.clear();
    _undoStack.push(_atom.value);
    _redoStack.clear();
    _updateReactiveState();
  }

  /// Number of undo steps currently available.
  int get historyLength => _undoStack.length - 1;

  void _apply(T value) {
    _isApplying = true;
    try {
      _atom.set(value);
    } finally {
      _isApplying = false;
    }
    _updateReactiveState();
  }

  void _updateReactiveState() {
    canUndo.set(_undoStack.length > 1);
    canRedo.set(_redoStack.isNotEmpty);
  }

  /// Stop tracking the atom and release resources.
  void dispose() {
    _atom.removeListener(_onAtomChanged);
    canUndo.dispose();
    canRedo.dispose();
  }
}

// ---------------------------------------------------------------------------
// Fixed-capacity ring buffer (LIFO — newest at the top)
// ---------------------------------------------------------------------------

class _RingBuffer<T> {
  final int capacity;
  late final List<T?> _data;
  int _start = 0;
  int _length = 0;

  _RingBuffer(this.capacity) : _data = List<T?>.filled(capacity, null);

  /// Push a value. Overwrites the oldest entry when full.
  void push(T value) {
    if (_length < capacity) {
      _data[(_start + _length) % capacity] = value;
      _length++;
    } else {
      _data[_start] = value;
      _start = (_start + 1) % capacity;
    }
  }

  /// Remove and return the newest value. Returns null if empty.
  T? pop() {
    if (_length == 0) return null;
    _length--;
    final index = (_start + _length) % capacity;
    final value = _data[index];
    _data[index] = null;
    return value;
  }

  /// Return the newest value without removing it. Returns null if empty.
  T? peek() {
    if (_length == 0) return null;
    return _data[(_start + _length - 1) % capacity];
  }

  void clear() {
    _data.fillRange(0, capacity, null);
    _start = 0;
    _length = 0;
  }

  int get length => _length;
}
