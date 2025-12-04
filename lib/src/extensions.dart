import 'dart:async';
import 'package:atomic_flutter/src/core.dart';
import 'package:atomic_flutter/src/widgets.dart';
import 'package:flutter/widgets.dart';

/// Extension methods for Atom class
extension AtomExtensions<T> on Atom<T> {
  /// Execute a side effect when the atom changes
  ///
  /// The effect is executed immediately with the current value
  /// when [runImmediately] is true,
  /// and then again whenever the value changes.
  ///
  /// Returns a function that can be called to stop the effect.
  VoidCallback effect(void Function(T value) effect,
      {bool runImmediately = false}) {
    if (runImmediately) {
      effect(value); // Run immediately if specified
    }
    addListener(effect); // Run on future changes

    return () => removeListener(effect);
  }

  /// Convert atom to a Stream
  ///
  /// The stream will emit the current value immediately,
  /// and then emit new values whenever the atom changes.
  Stream<T> asStream() {
    final controller = StreamController<T>.broadcast();

    // Add current value asynchronously
    scheduleMicrotask(() {
      if (!controller.isClosed) {
        controller.add(value);
      }
    });

    // Setup listener
    void listener(T value) {
      if (!controller.isClosed) {
        controller.add(value);
      }
    }

    addListener(listener);

    // Close controller when stream is cancelled
    controller.onCancel = () {
      removeListener(listener);
      if (!controller.isClosed) {
        controller.close();
      }
    };

    // Also close controller when atom is disposed
    onDispose(() {
      removeListener(listener);
      if (!controller.isClosed) {
        controller.close();
      }
    });

    return controller.stream;
  }

  /// Create a widget that only rebuilds when a specific part changes
  ///
  /// This is more efficient than using AtomBuilder when you only
  /// care about a specific part of a complex state object.
  ///
  /// [selector]: Function that selects a part of the atom's value
  /// [builder]: Builder function that receives the selected value
  Widget select<S>({
    required S Function(T state) selector,
    required Widget Function(BuildContext context, S selectedValue) builder,
  }) {
    return AtomSelector<T, S>(
      atom: this,
      selector: selector,
      builder: builder,
    );
  }

  /// Debounce updates to this atom
  ///
  /// Returns a new atom that updates only after [duration] has passed
  /// without any further updates to this atom.
  ///
  /// This is useful for handling frequent updates, like text field changes.
  Atom<T> debounce(Duration duration) {
    final debouncedAtom = Atom<T>(value, autoDispose: true);
    Timer? debounceTimer;

    void listener(T newValue) {
      debounceTimer?.cancel();
      debounceTimer = Timer(duration, () {
        debouncedAtom.set(newValue);
      });
    }

    addListener(listener);

    // Cleanup when derived atom is disposed
    debouncedAtom.onDispose(() {
      debounceTimer?.cancel();
      removeListener(listener);
    });

    // Cleanup derived atom when source atom is disposed
    onDispose(() {
      debounceTimer?.cancel();
      debouncedAtom.dispose();
    });

    return debouncedAtom;
  }

  /// Create an atom that throttles updates
  ///
  /// Returns a new atom that updates at most once every [duration],
  /// no matter how many updates the original atom receives.
  ///
  /// This is useful for limiting the rate of updates for performance reasons.
  Atom<T> throttle(Duration duration) {
    final throttledAtom = Atom<T>(value, autoDispose: true);
    DateTime? lastUpdate;

    void listener(T newValue) {
      try {
        final now = DateTime.now();
        if (lastUpdate == null || now.difference(lastUpdate!) >= duration) {
          throttledAtom.set(newValue);
          lastUpdate = now;
        }
      } catch (e) {
        if (Atom.debugMode) {
          print('AtomicFlutter: Throttle error in atom $id: $e');
        }
      }
    }

    addListener(listener);

    // Cleanup when derived atom is disposed
    throttledAtom.onDispose(() {
      removeListener(listener);
    });

    // Cleanup derived atom when source atom is disposed
    onDispose(() {
      throttledAtom.dispose();
    });

    return throttledAtom;
  }

  /// Map the atom's value to another type
  ///
  /// Returns a new atom that contains the mapped value and updates
  /// whenever this atom changes.
  Atom<R> map<R>(R Function(T value) mapper) {
    final mappedAtom = Atom<R>(mapper(value), autoDispose: true);

    void listener(T newValue) {
      try {
        mappedAtom.set(mapper(newValue));
      } catch (e) {
        // Handle mapping errors gracefully
        if (Atom.debugMode) {
          print('AtomicFlutter: Mapping error in atom $id: $e');
        }
      }
    }

    addListener(listener);

    // Cleanup when derived atom is disposed
    mappedAtom.onDispose(() {
      removeListener(listener);
    });

    // Cleanup derived atom when source atom is disposed
    onDispose(() {
      mappedAtom.dispose();
    });

    return mappedAtom;
  }

  /// Filter atom updates based on a predicate
  ///
  /// Returns a new atom that only updates when the predicate returns true.
  Atom<T> where(bool Function(T value) predicate) {
    final filteredAtom = Atom<T>(value, autoDispose: true);

    void listener(T newValue) {
      try {
        if (predicate(newValue)) {
          filteredAtom.set(newValue);
        }
      } catch (e) {
        if (Atom.debugMode) {
          print('AtomicFlutter: Filter predicate error in atom $id: $e');
        }
      }
    }

    addListener(listener);

    // Cleanup when derived atom is disposed
    filteredAtom.onDispose(() {
      removeListener(listener);
    });

    // Cleanup derived atom when source atom is disposed
    onDispose(() {
      filteredAtom.dispose();
    });

    return filteredAtom;
  }

  /// Combine this atom with another atom
  ///
  /// Returns a new atom containing a tuple of both values.
  Atom<(T, R)> combine<R>(Atom<R> other) {
    final combinedAtom = Atom<(T, R)>((value, other.value), autoDispose: true);

    void updateCombined() {
      try {
        combinedAtom.set((value, other.value));
      } catch (e) {
        if (Atom.debugMode) {
          print('AtomicFlutter: Combine error in atom $id: $e');
        }
      }
    }

    void thisListener(T _) => updateCombined();
    void otherListener(R _) => updateCombined();

    addListener(thisListener);
    other.addListener(otherListener);

    // Cleanup when combined atom is disposed
    combinedAtom.onDispose(() {
      removeListener(thisListener);
      other.removeListener(otherListener);
    });

    // Cleanup combined atom when either source atom is disposed
    onDispose(() {
      combinedAtom.dispose();
    });

    other.onDispose(() {
      combinedAtom.dispose();
    });

    return combinedAtom;
  }

  /// Create a computed atom that depends on this atom
  ///
  /// This is a convenience method for creating computed atoms.
  Atom<R> compute<R>(R Function(T value) computation) {
    return computed<R>(
      () => computation(value),
      tracked: [this],
      autoDispose: true,
    );
  }
}

/// Batch multiple atom updates together
void batchAtomUpdates(void Function() updates) {
  // Simple implementation - could be enhanced with global batching
  updates();
}

/// Create multiple atoms at once
Map<String, Atom<T>> createAtoms<T>(Map<String, T> initialValues) {
  return initialValues.map(
    (key, value) => MapEntry(key, Atom<T>(value, id: key)),
  );
}
