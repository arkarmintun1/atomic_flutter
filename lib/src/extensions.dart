import 'dart:async';

import 'package:atomic_flutter/src/core.dart';
import 'package:flutter/foundation.dart';

/// Extension methods for Atom class
extension AtomExtensions<T> on Atom<T> {
  /// Execute a side effect when the atom changes
  ///
  /// The effect is executed immediately with the current value
  /// when [runImmediately] is true,
  /// and then again whenever the value changes.
  ///
  /// Returns a function that can be called to stop the effect.
  VoidCallback effect(
    void Function(T value) fn, {
    bool runImmediately = true,
  }) {
    if (runImmediately) {
      fn(value);
    }
    addListener(fn);

    return () => removeListener(fn);
  }

  /// Convert atom to a Stream
  ///
  /// The stream will emit the current value immediately,
  /// and then emit new values whenever the atom changes.
  Stream<T> asStream() {
    late StreamController<T> controller;
    void Function(T)? listener;
    VoidCallback? removeDisposeHook;

    void detach() {
      final l = listener;
      if (l != null) removeListener(l);
      listener = null;
      removeDisposeHook?.call();
      removeDisposeHook = null;
    }

    controller = StreamController<T>(
      onListen: () {
        // Emit current value asynchronously once the subscriber is attached
        scheduleMicrotask(() {
          if (!controller.isClosed) {
            controller.add(value);
          }
        });

        void forward(T newValue) {
          if (!controller.isClosed) {
            controller.add(newValue);
          }
        }

        listener = forward;
        addListener(forward);
      },
      onCancel: () {
        detach();
        if (!controller.isClosed) {
          controller.close();
        }
      },
    );

    // Close controller when atom is disposed. The hook is removed again when
    // the stream is cancelled so long-lived atoms don't accumulate callbacks.
    removeDisposeHook = onDispose(() {
      removeDisposeHook = null;
      detach();
      if (!controller.isClosed) {
        controller.close();
      }
    });

    return controller.stream;
  }

  /// Derive a focused atom from a slice of this atom's state.
  ///
  /// The returned atom only updates when the selected value actually changes,
  /// making it efficient for large state objects where only part of the state
  /// is relevant to a given widget or computation.
  ///
  /// ```dart
  /// final userAtom = Atom<User>(User(name: 'Alice', role: 'admin'));
  ///
  /// final nameAtom = userAtom.select((u) => u.name);
  /// final roleAtom = userAtom.select((u) => u.role);
  ///
  /// // nameAtom only updates when u.name changes — role updates are ignored
  /// AtomBuilder(atom: nameAtom, builder: (ctx, name) => Text(name));
  ///
  /// // Composable with other extensions
  /// final greeting = computed(
  ///   () => 'Hello, ${nameAtom.value}!',
  ///   tracked: [nameAtom],
  /// );
  /// ```
  ///
  /// [selector]: Function that picks a slice of the atom's value
  /// [equals]: Optional custom equality for the selected value
  Atom<S> select<S>(
    S Function(T state) selector, {
    bool Function(S, S)? equals,
  }) {
    return computed<S>(
      () => selector(value),
      tracked: [this],
      autoDispose: true,
      equals: equals,
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
        if (!debouncedAtom.isDisposed) {
          debouncedAtom.set(newValue);
        }
      });
    }

    addListener(listener);

    // Cleanup derived atom when source atom is disposed
    final removeSourceHook = onDispose(() {
      debounceTimer?.cancel();
      debouncedAtom.dispose();
    });

    // Cleanup when derived atom is disposed. Also unregister the source
    // hook so long-lived sources don't accumulate dispose callbacks.
    debouncedAtom.onDispose(() {
      debounceTimer?.cancel();
      removeListener(listener);
      removeSourceHook();
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
    Timer? trailingTimer;
    T? pendingValue;
    bool hasPending = false;

    void listener(T newValue) {
      try {
        final now = DateTime.now();
        if (lastUpdate == null || now.difference(lastUpdate!) >= duration) {
          // Leading edge — emit immediately
          throttledAtom.set(newValue);
          lastUpdate = now;
          hasPending = false;
          trailingTimer?.cancel();
          trailingTimer = null;
        } else {
          // Inside throttle window — queue trailing emission
          pendingValue = newValue;
          hasPending = true;
          trailingTimer?.cancel();
          final remaining = duration - now.difference(lastUpdate!);
          trailingTimer = Timer(remaining, () {
            if (hasPending && !throttledAtom.isDisposed) {
              throttledAtom.set(pendingValue as T);
              lastUpdate = DateTime.now();
              hasPending = false;
            }
          });
        }
      } catch (e) {
        if (Atom.debugMode) {
          debugPrint('AtomicFlutter: Throttle error in atom $id: $e');
        }
      }
    }

    addListener(listener);

    // Cleanup derived atom when source atom is disposed
    final removeSourceHook = onDispose(() {
      trailingTimer?.cancel();
      throttledAtom.dispose();
    });

    // Cleanup when derived atom is disposed. Also unregister the source
    // hook so long-lived sources don't accumulate dispose callbacks.
    throttledAtom.onDispose(() {
      trailingTimer?.cancel();
      removeListener(listener);
      removeSourceHook();
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
          debugPrint('AtomicFlutter: Mapping error in atom $id: $e');
        }
      }
    }

    addListener(listener);

    // Cleanup derived atom when source atom is disposed
    final removeSourceHook = onDispose(() {
      mappedAtom.dispose();
    });

    // Cleanup when derived atom is disposed. Also unregister the source
    // hook so long-lived sources don't accumulate dispose callbacks.
    mappedAtom.onDispose(() {
      removeListener(listener);
      removeSourceHook();
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
          debugPrint('AtomicFlutter: Filter predicate error in atom $id: $e');
        }
      }
    }

    addListener(listener);

    // Cleanup derived atom when source atom is disposed
    final removeSourceHook = onDispose(() {
      filteredAtom.dispose();
    });

    // Cleanup when derived atom is disposed. Also unregister the source
    // hook so long-lived sources don't accumulate dispose callbacks.
    filteredAtom.onDispose(() {
      removeListener(listener);
      removeSourceHook();
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
          debugPrint('AtomicFlutter: Combine error in atom $id: $e');
        }
      }
    }

    void thisListener(T _) => updateCombined();
    void otherListener(R _) => updateCombined();

    addListener(thisListener);
    other.addListener(otherListener);

    // Cleanup when combined atom is disposed
    // Cleanup combined atom when either source atom is disposed.
    // Use removal functions to prevent the second source's callback from
    // running after the combined atom is already disposed.
    late final VoidCallback removeThisDispose;
    late final VoidCallback removeOtherDispose;

    combinedAtom.onDispose(() {
      removeListener(thisListener);
      other.removeListener(otherListener);
      // Unregister the source hooks so long-lived sources don't accumulate
      // dispose callbacks when the combined atom goes away first.
      removeThisDispose();
      removeOtherDispose();
    });

    removeThisDispose = onDispose(() {
      removeOtherDispose();
      combinedAtom.dispose();
    });

    removeOtherDispose = other.onDispose(() {
      removeThisDispose();
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


