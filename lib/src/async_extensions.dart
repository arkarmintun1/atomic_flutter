import 'dart:async';
import 'package:flutter/widgets.dart';

import 'async_atom.dart';
import 'core.dart';

/// Extensions for AsyncAtom
extension AsyncAtomExtensions<T> on AsyncAtom<T> {
  /// Create a debounced async operation
  AsyncAtom<T> debounceAsync(Duration duration) {
    final debouncedAtom = AsyncAtom<T>(
      initialValue: value,
      autoDispose: true,
    );

    Timer? debounceTimer;

    addListener((asyncValue) {
      debounceTimer?.cancel();
      debounceTimer = Timer(duration, () {
        debouncedAtom.set(asyncValue);
      });
    });

    debouncedAtom.onDispose(() {
      debounceTimer?.cancel();
    });

    return debouncedAtom;
  }

  /// Map the success value to another type
  AsyncAtom<R> mapAsync<R>(R Function(T data) mapper) {
    final mappedAtom = AsyncAtom<R>(autoDispose: true);

    addListener((asyncValue) {
      mappedAtom.set(asyncValue.map(mapper));
    });

    return mappedAtom;
  }

  /// Execute operation only if atom is not currently loading
  Future<T?> executeIfNotLoading(Future<T> Function() operation) async {
    if (!value.isLoading) {
      return execute(operation);
    }
    return null;
  }

  /// Execute with automatic retry on failure
  Future<T> executeWithRetry(
    Future<T> Function() operation, {
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        return await execute(operation);
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        await Future.delayed(delay * attempts); // Exponential backoff
      }
    }

    throw StateError('This should never be reached');
  }

  /// Chain async operations
  AsyncAtom<R> chain<R>(Future<R> Function(T data) nextOperation) {
    final chainedAtom = AsyncAtom<R>(autoDispose: true);

    addListener((asyncValue) {
      if (asyncValue.hasValue) {
        chainedAtom.execute(() => nextOperation(asyncValue.value));
      } else if (asyncValue.hasError) {
        chainedAtom.setError(asyncValue.error!, asyncValue.stackTrace!);
      } else if (asyncValue.isLoading) {
        // Fix: Remove type parameter
        chainedAtom.set(const AsyncValue.loading());
      }
    });

    return chainedAtom;
  }

  /// Create a cached version of async operations
  AsyncAtom<T> cached({
    Duration? ttl,
    bool refreshOnError = true,
  }) {
    final cachedAtom = AsyncAtom<T>(initialValue: value, autoDispose: true);
    Timer? ttlTimer;

    addListener((asyncValue) {
      if (asyncValue.hasValue) {
        cachedAtom.set(asyncValue);

        // Set TTL timer if provided
        if (ttl != null) {
          ttlTimer?.cancel();
          ttlTimer = Timer(ttl, () {
            if (cachedAtom.value.hasValue) {
              cachedAtom.clear();
            }
          });
        }
      } else if (asyncValue.hasError && refreshOnError) {
        cachedAtom.set(asyncValue);
      } else if (asyncValue.isLoading && !cachedAtom.value.hasValue) {
        cachedAtom.set(asyncValue);
      }
    });

    cachedAtom.onDispose(() {
      ttlTimer?.cancel();
    });

    return cachedAtom;
  }
}

/// Extensions for regular Atom to create AsyncAtom
extension AtomAsyncExtensions<T> on Atom<T> {
  /// Convert a regular atom to an AsyncAtom
  ///
  /// The AsyncAtom will inherit the same auto-dispose settings as the original atom.
  AsyncAtom<T> toAsync() {
    return AsyncAtom<T>(
      initialValue: AsyncValue.success(value),
      id: '${id}_async',
      autoDispose: autoDispose,
      disposeTimeout: disposeTimeout,
    );
  }

  /// Create an async atom that executes an operation when this atom changes
  AsyncAtom<R> asyncMap<R>(Future<R> Function(T value) operation) {
    final asyncAtom = AsyncAtom<R>(autoDispose: true);

    // Execute initially
    asyncAtom.execute(() => operation(value));

    // Execute when atom changes
    addListener((newValue) {
      asyncAtom.execute(() => operation(newValue));
    });

    return asyncAtom;
  }
}

/// Create async computed atoms
AsyncAtom<R> computedAsync<R>(
  Future<R> Function() compute, {
  List<Atom> tracked = const [],
  String? id,
  bool autoDispose = true,
  Duration? disposeTimeout,
  Duration debounce = const Duration(milliseconds: 500),
}) {
  final asyncAtom = AsyncAtom<R>(
    id: id,
    autoDispose: autoDispose,
    disposeTimeout: disposeTimeout,
  );

  Timer? debounceTimer;
  final List<VoidCallback> cleanupFunctions = [];

  void executeComputation() {
    debounceTimer?.cancel();
    debounceTimer = Timer(debounce, () {
      asyncAtom.execute(compute);
    });
  }

  // Listen to all tracked atoms
  for (final atom in tracked) {
    void listener(dynamic _) => executeComputation();
    atom.addListener(listener);
    cleanupFunctions.add(() => atom.removeListener(listener));
  }

  // Execute initial computation
  executeComputation();

  // Cleanup
  asyncAtom.onDispose(() {
    debounceTimer?.cancel();
    for (final cleanup in cleanupFunctions) {
      cleanup();
    }
  });

  return asyncAtom;
}

/// Create an async atom that combines multiple async atoms
AsyncAtom<List<T>> combineAsync<T>(List<AsyncAtom<T>> atoms) {
  final combinedAtom = AsyncAtom<List<T>>(autoDispose: true);

  void updateCombined() {
    final values = <T>[];
    bool hasError = false;
    bool isLoading = false;
    Object? firstError;
    StackTrace? firstStackTrace;

    for (final atom in atoms) {
      final asyncValue = atom.value;

      if (asyncValue.hasError) {
        hasError = true;
        firstError ??= asyncValue.error;
        firstStackTrace ??= asyncValue.stackTrace;
      } else if (asyncValue.isLoading) {
        isLoading = true;
      } else if (asyncValue.hasValue) {
        values.add(asyncValue.value);
      }
    }

    if (hasError) {
      combinedAtom.setError(firstError!, firstStackTrace!);
    } else if (isLoading) {
      // Fix: Use const constructor without type parameters
      combinedAtom.set(const AsyncValue.loading());
    } else if (values.length == atoms.length) {
      combinedAtom.setData(values);
    }
  }

  // Listen to all atoms
  final cleanupFunctions = <VoidCallback>[];
  for (final atom in atoms) {
    void listener(AsyncValue<T> _) => updateCombined();
    atom.addListener(listener);
    cleanupFunctions.add(() => atom.removeListener(listener));
  }

  // Initial update
  updateCombined();

  // Cleanup
  combinedAtom.onDispose(() {
    for (final cleanup in cleanupFunctions) {
      cleanup();
    }
  });

  return combinedAtom;
}
