import 'dart:async';

import 'package:flutter/widgets.dart';

/// A single atomic unit of state
class Atom<T> {
  final String _id;
  T _value;
  final Set<_AtomListener<T>> _listeners = {};
  final Set<WeakReference<Atom>> _dependencies = {};
  final Set<WeakReference<Atom>> _dependents = {};
  bool _isBatching = false;
  bool _isDirty = false;

  // Memory management properties
  int _refCount = 0;
  Timer? _disposeTimer;
  final bool _autoDispose;
  final Duration? _disposeTimeout;

  // Dispose callback for cleanup
  final List<VoidCallback> _disposeCallbacks = [];

  // Static configuration
  static Duration defaultDisposeTimeout = const Duration(minutes: 2);
  static bool debugMode = false;

  /// Create a new atom with initial value
  ///
  /// [value]: The initial state value
  /// [id]: Optional identifier for debugging (auto-generated if not provided)
  /// [autoDispose]: Whether this atom should be automatically disposed when no longer used
  /// [disposeTimeout]: How long to wait before disposing unused atoms
  Atom(
    this._value, {
    String? id,
    bool autoDispose = true,
    Duration? disposeTimeout,
  })  : _id = id ?? 'atom_${identityHashCode(_value)}',
        _autoDispose = autoDispose,
        _disposeTimeout = disposeTimeout {
    if (debugMode) {
      print('AtomicFlutter: Created atom $_id with initial value: $_value');
    }
  }

  /// Current value of the atom
  T get value => _value;

  /// Unique ID of this atom
  String get id => _id;

  /// Update the atom value with explicit mutation
  ///
  /// This will notify all listeners if the value actually changes.
  /// Uses `==` comparison to determine if the value has changed.
  void set(T newValue) {
    if (identical(_value, newValue) && _value == newValue) return;

    final oldValue = _value;
    _value = newValue;

    if (debugMode) {
      print('Atomic: Updated atom $_id: $oldValue -> $newValue');
    }

    _notifyListeners();
  }

  /// Update the atom value using a transformer function
  ///
  /// [updater]: A function that receives the current value and returns a new value
  void update(T Function(T current) updater) {
    set(updater(_value));
  }

  void _notifyListeners() {
    if (_isBatching) {
      _isDirty = true;
      return;
    }

    // First notify computed atoms that depend on this atom
    final activeDependents = <Atom>[];

    // Clean up any dead references while processing
    _dependents.removeWhere((weakRef) {
      final dependent = weakRef.target;
      if (dependent == null) return true; // Remove dead reference

      activeDependents.add(dependent);
      return false;
    });

    // Notify active dependents
    for (final dependent in activeDependents) {
      (dependent as _ComputedAtom)._computeValue();
    }

    // Then notify UI listeners
    for (final listener in _listeners) {
      listener._notify(_value);
    }
  }

  /// Start a batch update to prevent intermediate notifications
  ///
  /// [actions]: A function that performs multiple state updates
  ///
  /// Use this when you need to update multiple related atoms and
  /// want to prevent UI from rebuilding until all updates are complete.
  void batch(void Function() actions) {
    _isBatching = true;
    try {
      actions();
    } finally {
      _isBatching = false;
      if (_isDirty) {
        _isDirty = false;
        _notifyListeners();
      }
    }
  }

  /// Add a listener to this atom
  ///
  /// [listener]: A function that will be called with the new value when it changes
  void addListener(void Function(T value) listener) {
    final atomListener = _AtomListener<T>(listener);
    if (!_listeners.contains(atomListener)) {
      _listeners.add(atomListener);
      _incrementRefCount();
    }
  }

  /// Remove a listener from this atom
  ///
  /// [listener]: The function that was previously added with addListener
  void removeListener(void Function(T value) listener) {
    final atomListener = _AtomListener<T>(listener);
    if (_listeners.contains(atomListener)) {
      _listeners.remove(atomListener);
      _decrementRefCount();
    }
  }

  /// Register a function to be called when this atom is disposed
  ///
  /// [callback]: A function that will be called when the atom is disposed
  void onDispose(VoidCallback callback) {
    _disposeCallbacks.add(callback);
  }

  /// Increment the reference counter
  void _incrementRefCount() {
    _refCount++;

    // Cancel any pending dispose timer
    _disposeTimer?.cancel();
    _disposeTimer = null;

    if (debugMode) {
      print('Atomic: Incremented ref count for atom $_id: $_refCount');
    }
  }

  /// Decrement the reference counter and potentially schedule disposal
  void _decrementRefCount() {
    _refCount--;

    if (debugMode) {
      print('Atomic: Decremented ref count for atom $_id: $_refCount');
    }

    // If auto-dispose is enabled and no more references, schedule disposal
    if (_autoDispose && _refCount <= 0 && _listeners.isEmpty) {
      _scheduleDispose();
    }
  }

  /// Schedule atom for disposal if it remains unused
  void _scheduleDispose() {
    // Cancel any existing timer
    _disposeTimer?.cancel();

    // Set new timer for disposal
    final timeout = _disposeTimeout ?? defaultDisposeTimeout;

    if (debugMode) {
      print(
          'Atomic: Scheduling dispose for atom $_id in ${timeout.inSeconds} seconds');
    }

    _disposeTimer = Timer(timeout, () {
      // Double-check that it's still unused before disposing
      if (_refCount <= 0 && _listeners.isEmpty) {
        dispose();
      }
    });
  }

  /// Explicitly dispose this atom
  ///
  /// This will remove all listeners and references to this atom.
  void dispose() {
    if (debugMode) {
      print('Atomic: Disposing atom $_id');
    }

    for (final callback in _disposeCallbacks) {
      callback();
    }
    _disposeCallbacks.clear();

    // Clear all listeners
    _listeners.clear();

    // Remove this atom from all dependencies
    for (final weakRef in _dependencies) {
      final dep = weakRef.target;
      if (dep != null) {
        dep._dependents.removeWhere((ref) => ref.target == this);
      }
    }

    // Clear references
    _dependencies.clear();
    _dependents.clear();

    // Cancel any pending timer
    _disposeTimer?.cancel();
    _disposeTimer = null;
  }

  @override
  String toString() => 'Atom<$T>($_id, $_value, refs: $_refCount)';
}

class _ComputedAtom<T> extends Atom<T> {
  final Function() _computeFunction;

  _ComputedAtom(
    T initialValue,
    this._computeFunction, {
    String? id,
    bool autoDispose = true,
    Duration? disposeTimeout,
  }) : super(
          initialValue,
          id: id,
          autoDispose: autoDispose,
          disposeTimeout: disposeTimeout,
        );

  void _computeValue() {
    set(_computeFunction());
  }
}

/// Create a derived atom that depends on others
///
/// [compute]: A function that computes the derived value
/// [tracked]: List of atoms this computation depends on
/// [id]: Optional identifier for debugging
/// [autoDispose]: Whether this atom should be auto-disposed when no longer used
/// [disposeTimeout]: How long to wait before disposing unused computed atoms
Atom<R> computed<R>(
  R Function() compute, {
  List<Atom> tracked = const [],
  String? id,
  bool autoDispose = true,
  Duration? disposeTimeout,
}) {
  final derivedAtom = _ComputedAtom<R>(
    compute(),
    compute,
    id: id,
    autoDispose: autoDispose,
    disposeTimeout: disposeTimeout,
  );

  for (final atom in tracked) {
    // Store weak references to dependencies
    derivedAtom._dependencies.add(WeakReference(atom));

    // Add this atom as a dependent of its dependencies
    atom._dependents.add(WeakReference(derivedAtom));
  }

  return derivedAtom;
}

/// Internal listener class to manage subscriptions
class _AtomListener<T> {
  final void Function(T value) callback;
  final int _callbackIdentity;

  _AtomListener(this.callback) : _callbackIdentity = callback.hashCode;

  void _notify(T value) => callback(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _AtomListener && _callbackIdentity == other._callbackIdentity;

  @override
  int get hashCode => _callbackIdentity;
}
