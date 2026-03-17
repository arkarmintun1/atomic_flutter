import 'dart:async';
import 'dart:collection';

import 'package:atomic_flutter/src/debug.dart';
import 'package:atomic_flutter/src/middleware.dart';
import 'package:flutter/widgets.dart';

/// Per-atom value transformer. Receives the old and proposed new value,
/// returns the value to actually store. Return [oldValue] to block the update.
typedef AtomTransformer<T> = T Function(T oldValue, T newValue);

/// A single atomic unit of state
class Atom<T> {
  final String _id;
  T _value;
  final bool Function(T, T)? _equals;
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

  // Per-atom middleware transformers
  final List<AtomTransformer<T>> _localMiddleware;

  // Static configuration
  static Duration defaultDisposeTimeout = const Duration(minutes: 2);
  static bool debugMode = false;

  // Global middleware applied to every atom's set() call
  static final List<AtomMiddleware> _globalMiddleware = [];

  // Global batch state — atoms modified during a batch defer notifications
  static bool _globalBatching = false;
  static final LinkedHashSet<Atom> _globalDirtyAtoms = LinkedHashSet();

  /// Register [middleware] globally — it will be called for every atom.
  ///
  /// ```dart
  /// Atom.addMiddleware(const LoggingMiddleware());
  /// ```
  static void addMiddleware(AtomMiddleware middleware) =>
      _globalMiddleware.add(middleware);

  /// Remove a previously registered global [middleware].
  static void removeMiddleware(AtomMiddleware middleware) =>
      _globalMiddleware.remove(middleware);

  /// Remove all global middleware. Useful in tests.
  static void clearMiddleware() => _globalMiddleware.clear();

  /// Create a new atom with initial value
  ///
  /// [value]: The initial state value
  /// [id]: Optional identifier for debugging (auto-generated if not provided)
  /// [autoDispose]: Whether this atom should be automatically disposed when no longer used
  /// [disposeTimeout]: How long to wait before disposing unused atoms
  /// [equals]: Optional custom equality function. When provided, replaces the
  /// default `==` check to determine whether a new value should trigger
  /// listener notifications. Useful for collections or objects where reference
  /// equality differs from value equality:
  ///
  /// ```dart
  /// final listAtom = Atom<List<int>>([], equals: listEquals);
  /// final userAtom = Atom<User>(User.empty(), equals: (a, b) => a.id == b.id);
  /// ```
  Atom(
    this._value, {
    String? id,
    bool autoDispose = true,
    Duration? disposeTimeout,
    bool Function(T, T)? equals,
    List<AtomTransformer<T>>? middleware,
  })  : _id = id ?? 'atom_${identityHashCode(_value)}',
        _autoDispose = autoDispose,
        _disposeTimeout = disposeTimeout,
        _equals = equals,
        _localMiddleware = middleware ?? const [] {
    if (debugMode) {
      AtomDebugger.register(this);
    }
  }

  /// Current value of the atom
  T get value => _value;

  /// Unique ID of this atom
  String get id => _id;

  /// Whether this atom should be automatically disposed when no longer used
  bool get autoDispose => _autoDispose;

  /// How long to wait before disposing unused atoms
  Duration? get disposeTimeout => _disposeTimeout;

  /// Number of active listeners
  int get refCount => _refCount;

  /// Whether this atom has any listeners
  bool get hasListeners => _listeners.isNotEmpty;

  /// Debug-only: IDs of atoms this atom depends on.
  ///
  /// Returns an empty list if debug mode is off or no dependencies exist.
  /// Used by the DevTools extension to build the dependency graph.
  List<String> get debugDependencyIds {
    if (!debugMode) return const [];
    return _dependencies
        .map((ref) => ref.target?.id)
        .whereType<String>()
        .toList();
  }

  /// Debug-only: IDs of atoms that depend on this atom.
  ///
  /// Returns an empty list if debug mode is off or no dependents exist.
  /// Used by the DevTools extension to build the dependency graph.
  List<String> get debugDependentIds {
    if (!debugMode) return const [];
    return _dependents
        .map((ref) => ref.target?.id)
        .whereType<String>()
        .toList();
  }

  /// Debug-only: Whether this atom is a computed atom.
  ///
  /// Used by the DevTools extension to determine node type in the graph.
  bool get isComputed => this is _ComputedAtom;

  /// Debug-only: Number of listeners attached to this atom.
  int get listenerCount => _listeners.length;

  /// Update the atom value with explicit mutation.
  ///
  /// Runs all registered middleware (per-atom transformers first, then global)
  /// before storing the value. Listeners are only notified if the value
  /// actually changes (using the custom [equals] function if provided,
  /// otherwise falling back to `identical` + `==`).
  void set(T newValue) {
    T result = newValue;
    for (final t in _localMiddleware) {
      result = t(_value, result);
    }
    for (final mw in Atom._globalMiddleware) {
      result = mw.onSet(this, _value, result);
    }
    _setDirect(result);
  }

  /// Stores [newValue] and notifies listeners, bypassing middleware.
  ///
  /// Used internally by computed atoms and async state transitions where
  /// the value is derived by the framework, not driven by user code.
  void _setDirect(T newValue) {
    final isEqual = _equals != null
        ? _equals(_value, newValue)
        : (identical(_value, newValue) || _value == newValue);
    if (isEqual) return;

    _value = newValue;

    if (debugMode) {
      AtomPerformanceMonitor.recordUpdate(_id);
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

    if (Atom._globalBatching) {
      Atom._globalDirtyAtoms.add(this);
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

    // Notify active dependents with error handling
    for (final dependent in activeDependents) {
      if (dependent is _ComputedAtom) {
        try {
          dependent._computeValue();
        } catch (e, stackTrace) {
          if (debugMode) {
            print(
              'AtomicFlutter: Error in computed atom "${dependent.id}" '
              'while recomputing from dependency "$_id": $e\n$stackTrace',
            );
          }
        }
      }
    }

    // Then notify UI listeners with error handling
    for (final listener in _listeners) {
      try {
        listener._notify(_value);
      } catch (e, stackTrace) {
        if (debugMode) {
          print(
            'AtomicFlutter: Error in listener for atom "$_id": $e\n$stackTrace',
          );
        }
      }
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
  }

  /// Decrement the reference counter and potentially schedule disposal
  void _decrementRefCount() {
    _refCount--;

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
      print('AtomicFlutter: Disposing atom $_id');
      AtomDebugger.unregister(this);
    }

    for (final callback in _disposeCallbacks) {
      try {
        callback();
      } catch (e) {
        if (debugMode) {
          print('AtomicFlutter: Error in dispose callback for atom $_id: $e');
        }
      }
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

    // Reset reference count to prevent further disposal attempts
    _refCount = 0;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Atom && _id == other._id;

  @override
  int get hashCode => _id.hashCode;

  @override
  String toString() => 'Atom<$T>($_id, $_value, refs: $_refCount)';
}

class _ComputedAtom<T> extends Atom<T> {
  final T Function() _computeFunction;

  _ComputedAtom(
    super.initialValue,
    this._computeFunction, {
    super.id,
    super.autoDispose,
    super.disposeTimeout,
    super.equals,
  });

  void _computeValue() {
    _setDirect(_computeFunction());
  }

  @override
  void set(T newValue) {
    throw UnsupportedError(
      'Cannot directly set value of computed atom "$id". '
      'Update its dependencies instead.',
    );
  }

  @override
  void update(T Function(T current) updater) {
    throw UnsupportedError(
      'Cannot directly update value of computed atom "$id". '
      'Update its dependencies instead.',
    );
  }
}

/// Create a derived atom that depends on others
///
/// [compute]: A function that computes the derived value
/// [tracked]: List of atoms this computation depends on
/// [id]: Optional identifier for debugging
/// [autoDispose]: Whether this atom should be auto-disposed when no longer used
/// [disposeTimeout]: How long to wait before disposing unused computed atoms
/// [equals]: Optional custom equality function (see [Atom] constructor)
///
/// Throws [StateError] if circular dependencies are detected.
Atom<R> computed<R>(
  R Function() compute, {
  List<Atom> tracked = const [],
  String? id,
  bool autoDispose = true,
  Duration? disposeTimeout,
  bool Function(R, R)? equals,
}) {
  final derivedAtom = _ComputedAtom<R>(
    compute(),
    compute,
    id: id,
    autoDispose: autoDispose,
    disposeTimeout: disposeTimeout,
    equals: equals,
  );

  // Check for circular dependencies before establishing connections
  for (final atom in tracked) {
    final path = _findCyclePath(atom, derivedAtom, [atom.id], {});
    if (path != null) {
      // Prepend derivedAtom so the displayed cycle starts and ends with it:
      // e.g. "priceAtom → discountAtom → totalAtom → priceAtom"
      final cycleDisplay = [derivedAtom.id, ...path].join(' → ');
      throw StateError(
        'Circular dependency detected:\n  $cycleDisplay',
      );
    }
  }

  for (final atom in tracked) {
    // Store weak references to dependencies
    derivedAtom._dependencies.add(WeakReference(atom));

    // Add this atom as a dependent of its dependencies
    atom._dependents.add(WeakReference(derivedAtom));
  }

  return derivedAtom;
}

/// Update multiple atoms in a single batch — listeners are notified only
/// after all updates in [updates] have completed.
///
/// Without this, each `set()` immediately notifies listeners, causing one
/// rebuild per atom. With `atomicUpdate`, a widget that depends on several
/// atoms rebuilds exactly once after the batch finishes.
///
/// ```dart
/// atomicUpdate(() {
///   counterAtom.set(5);
///   nameAtom.set('Alice');
///   cartAtom.clear();
/// });
/// ```
///
/// Throws if [updates] throws — dirty atoms are not flushed in that case,
/// leaving state as it was before the failed updates.
void atomicUpdate(void Function() updates) {
  Atom._globalBatching = true;
  try {
    updates();
  } catch (_) {
    // Discard any pending notifications from the failed batch
    Atom._globalDirtyAtoms.clear();
    Atom._globalBatching = false;
    rethrow;
  }
  Atom._globalBatching = false;

  // Flush dirty atoms in insertion order (first modified = first notified)
  final dirty = List<Atom>.of(Atom._globalDirtyAtoms);
  Atom._globalDirtyAtoms.clear();
  for (final atom in dirty) {
    atom._notifyListeners();
  }
}

/// Returns the dependency path from [source] to [target] if one exists,
/// or null if no path exists.
///
/// [path] is a mutable list pre-seeded with [source.id] by the caller.
/// On success it is populated with every node id from source to target
/// (inclusive). On failure its contents are undefined.
List<String>? _findCyclePath(
  Atom source,
  Atom target,
  List<String> path,
  Set<Atom> visited,
) {
  if (visited.contains(source)) return null;
  visited.add(source);

  for (final weakRef in source._dependencies) {
    final dep = weakRef.target;
    if (dep == null) continue;

    path.add(dep.id);
    if (dep == target) return List.from(path);

    final result = _findCyclePath(dep, target, path, visited);
    if (result != null) return result;

    path.removeLast(); // backtrack
  }

  return null;
}

/// Atom family for creating related atoms with different keys
class AtomFamily<T, K> {
  final Map<K, Atom<T>> _atoms = {};
  final Atom<T> Function(K key) _creator;

  AtomFamily(this._creator);

  /// Get or create an atom for the given key
  Atom<T> call(K key) {
    return _atoms.putIfAbsent(key, () => _creator(key));
  }

  /// Dispose a specific atom by key
  void disposeKey(K key) {
    final atom = _atoms.remove(key);
    atom?.dispose();
  }

  /// Dispose all atoms in this family
  void dispose() {
    for (final atom in _atoms.values) {
      atom.dispose();
    }
    _atoms.clear();
  }

  /// Get all active keys
  Iterable<K> get keys => _atoms.keys;

  /// Get all active atoms
  Iterable<Atom<T>> get atoms => _atoms.values;
}

/// Internal listener class to manage subscriptions
class _AtomListener<T> {
  final void Function(T value) callback;

  _AtomListener(this.callback);

  void _notify(T value) => callback(value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _AtomListener<T> && identical(callback, other.callback));

  @override
  int get hashCode => identityHashCode(callback);
}
