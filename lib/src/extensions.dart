import 'dart:async';
import 'package:atomic_flutter/src/core.dart';
import 'package:atomic_flutter/src/widgets.dart';
import 'package:flutter/widgets.dart';

/// Extension methods for Atom class
extension AtomExtensions<T> on Atom<T> {
  /// Execute a side effect when the atom changes
  ///
  /// The effect is executed immediately with the current value,
  /// and then again whenever the value changes.
  ///
  /// Returns a function that can be called to stop the effect.
  VoidCallback effect(void Function(T value) effect) {
    effect(value); // Run immediately with current value
    addListener(effect); // Run on future changes

    return () => removeListener(effect);
  }

  /// Convert atom to a Stream
  ///
  /// The stream will emit the current value immediately,
  /// and then emit new values whenever the atom changes.
  Stream<T> asStream() {
    final controller = StreamController<T>.broadcast();

    // Add current value
    controller.add(value);

    // Setup listener
    void listener(T value) {
      if (!controller.isClosed) {
        controller.add(value);
      }
    }

    addListener(listener);

    // Close controller when stream is done
    controller.onCancel = () {
      removeListener(listener);
      controller.close();
    };

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

    addListener((newValue) {
      debounceTimer?.cancel();
      debounceTimer = Timer(duration, () {
        debouncedAtom.set(newValue);
      });
    });

    // Clean up when disposed
    debouncedAtom.onDispose(() {
      debounceTimer?.cancel();
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

    addListener((newValue) {
      final now = DateTime.now();
      if (lastUpdate == null || now.difference(lastUpdate!) >= duration) {
        throttledAtom.set(newValue);
        lastUpdate = now;
      }
    });

    return throttledAtom;
  }

  /// Map the atom's value to another type
  ///
  /// Returns a new atom that contains the mapped value and updates
  /// whenever this atom changes.
  Atom<R> map<R>(R Function(T value) mapper) {
    final mappedAtom = Atom<R>(mapper(value), autoDispose: true);

    addListener((newValue) {
      try {
        mappedAtom.set(mapper(newValue));
      } catch (e) {
        // Handle mapping errors gracefully
        if (Atom.debugMode) {
          print('AtomicFlutter: Mapping error in atom ${id}: $e');
        }
      }
    });

    return mappedAtom;
  }

  /// Filter atom updates based on a predicate
  ///
  /// Returns a new atom that only updates when the predicate returns true.
  Atom<T> where(bool Function(T value) predicate) {
    final filteredAtom = Atom<T>(value, autoDispose: true);

    addListener((newValue) {
      if (predicate(newValue)) {
        filteredAtom.set(newValue);
      }
    });

    return filteredAtom;
  }

  /// Combine this atom with another atom
  ///
  /// Returns a new atom containing a tuple of both values.
  Atom<(T, R)> combine<R>(Atom<R> other) {
    final combinedAtom = Atom<(T, R)>((value, other.value), autoDispose: true);

    void updateCombined() {
      combinedAtom.set((value, other.value));
    }

    addListener((_) => updateCombined());
    other.addListener((_) => updateCombined());

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
