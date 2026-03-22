import 'dart:async';

import 'core.dart';

/// A recorded state transition event for an AsyncAtom.
/// Only recorded when debug mode is enabled.
class AsyncAtomEvent {
  final String atomId;
  final DateTime timestamp;
  final String fromState;
  final String toState;
  final int durationMs;
  final String? error;

  const AsyncAtomEvent({
    required this.atomId,
    required this.timestamp,
    required this.fromState,
    required this.toState,
    required this.durationMs,
    this.error,
  });

  Map<String, dynamic> toJson() => {
        'atomId': atomId,
        'timestamp': timestamp.toIso8601String(),
        'fromState': fromState,
        'toState': toState,
        'durationMs': durationMs,
        'error': error,
      };
}

/// Global ring buffer for async events. Debug mode only.
class AsyncEventLog {
  static final List<AsyncAtomEvent> _events = [];
  static const int _maxEvents = 500;

  static void record(AsyncAtomEvent event) {
    if (!Atom.debugMode) return;
    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeAt(0);
    }
  }

  static List<AsyncAtomEvent> getEvents({String? atomId}) {
    if (atomId != null) {
      return _events.where((e) => e.atomId == atomId).toList();
    }
    return List.unmodifiable(_events);
  }

  static void clear() => _events.clear();
}

/// Represents the state of an async operation
enum AsyncState { idle, loading, success, error }

/// Container for async data with loading and error states
class AsyncValue<T> {
  final T? data;
  final Object? error;
  final StackTrace? stackTrace;
  final AsyncState state;

  const AsyncValue._({
    this.data,
    this.error,
    this.stackTrace,
    required this.state,
  });

  /// Create an idle state (no operation started)
  const AsyncValue.idle() : this._(state: AsyncState.idle);

  /// Create a loading state
  const AsyncValue.loading({T? data})
      : this._(data: data, state: AsyncState.loading);

  /// Create a success state with data
  const AsyncValue.success(T data)
      : this._(data: data, state: AsyncState.success);

  /// Create an error state
  const AsyncValue.error(Object error, StackTrace stackTrace, {T? data})
      : this._(
          data: data,
          error: error,
          stackTrace: stackTrace,
          state: AsyncState.error,
        );

  /// Whether the async operation is currently loading
  bool get isLoading => state == AsyncState.loading;

  /// Whether the operation completed successfully
  bool get hasValue => state == AsyncState.success;

  /// Whether the operation resulted in an error
  bool get hasError => state == AsyncState.error;

  /// Whether no operation has been started
  bool get isIdle => state == AsyncState.idle;

  /// Get the data or null if not available
  T? get valueOrNull => data;

  /// Get the data or throw if not available
  T get value {
    if (hasError) {
      throw error!;
    }
    if (!hasValue) {
      throw StateError('AsyncValue has no data (state: $state)');
    }
    return data as T;
  }

  /// Transform the data if present
  AsyncValue<R> map<R>(R Function(T data) mapper) {
    if (hasValue) {
      try {
        return AsyncValue.success(mapper(data as T));
      } catch (e, stack) {
        return AsyncValue.error(e, stack);
      }
    }

    return AsyncValue<R>._(
      error: error,
      stackTrace: stackTrace,
      state: state,
    );
  }

  /// Handle different states with callbacks
  R when<R>({
    required R Function() idle,
    required R Function() loading,
    required R Function(T data) success,
    required R Function(Object error, StackTrace stackTrace) error,
  }) {
    switch (state) {
      case AsyncState.idle:
        return idle();
      case AsyncState.loading:
        return loading();
      case AsyncState.success:
        return success(data as T);
      case AsyncState.error:
        return error(this.error!, stackTrace!);
    }
  }

  /// Handle different states with optional callbacks
  R maybeWhen<R>({
    R Function()? idle,
    R Function()? loading,
    R Function(T data)? success,
    R Function(Object error, StackTrace stackTrace)? error,
    required R Function() orElse,
  }) {
    switch (state) {
      case AsyncState.idle:
        return idle?.call() ?? orElse();
      case AsyncState.loading:
        return loading?.call() ?? orElse();
      case AsyncState.success:
        return success?.call(data as T) ?? orElse();
      case AsyncState.error:
        return error?.call(this.error!, stackTrace!) ?? orElse();
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AsyncValue<T> &&
          state == other.state &&
          data == other.data &&
          // Error states always compare unequal so retries that hit
          // the same error still trigger rebuilds.
          !hasError &&
          error == other.error;

  @override
  int get hashCode => hasError
      ? Object.hash(data, error, state, identityHashCode(this))
      : Object.hash(data, error, state);

  @override
  String toString() => 'AsyncValue<$T>($state, data: $data, error: $error)';
}

/// An atom that manages async operations and their states
class AsyncAtom<T> extends Atom<AsyncValue<T>> {
  int _operationId = 0;
  Future<T> Function()? _lastOperation;
  AsyncValue<T>? _stateBeforeLoading; // Store state before loading
  DateTime? _loadingStartTime;

  AsyncAtom({
    AsyncValue<T>? initialValue,
    String? id,
    bool autoDispose = true,
    Duration? disposeTimeout,
  }) : super(
          initialValue ?? const AsyncValue.idle(),
          id: id,
          autoDispose: autoDispose,
          disposeTimeout: disposeTimeout,
        );

  /// Execute an async operation.
  ///
  /// If a new [execute] call is made before this one completes, the previous
  /// operation is superseded: its result is still returned to the caller, but
  /// the atom's state is **not** updated. Callers that chain logic on the
  /// return value should check [value] to confirm the atom adopted the result.
  Future<T> execute(
    Future<T> Function() operation, {
    bool keepPreviousData = false,
  }) async {
    if (isDisposed) {
      throw StateError('Cannot execute on disposed AsyncAtom "$id"');
    }

    // Store current state before setting loading
    _stateBeforeLoading = value;

    final currentOperationId = ++_operationId;
    final fromState = value.state.name;

    // Record loading start time
    _loadingStartTime = DateTime.now();

    final previousData = keepPreviousData ? value.data : null;
    set(AsyncValue.loading(data: previousData));

    AsyncEventLog.record(AsyncAtomEvent(
      atomId: id,
      timestamp: _loadingStartTime!,
      fromState: fromState,
      toState: 'loading',
      durationMs: 0,
    ));

    try {
      final result = await operation();

      final isActive = !isDisposed && _operationId == currentOperationId;
      if (isActive) {
        final duration = DateTime.now().difference(_loadingStartTime!);
        set(AsyncValue.success(result));
        _stateBeforeLoading = null;

        AsyncEventLog.record(AsyncAtomEvent(
          atomId: id,
          timestamp: DateTime.now(),
          fromState: 'loading',
          toState: 'success',
          durationMs: duration.inMilliseconds,
        ));
      }

      return result;
    } catch (error, stackTrace) {
      if (!isDisposed && _operationId == currentOperationId) {
        final duration = DateTime.now().difference(_loadingStartTime!);
        set(AsyncValue.error(error, stackTrace, data: previousData));
        _stateBeforeLoading = null;

        AsyncEventLog.record(AsyncAtomEvent(
          atomId: id,
          timestamp: DateTime.now(),
          fromState: 'loading',
          toState: 'error',
          durationMs: duration.inMilliseconds,
          error: error.toString(),
        ));
      }

      rethrow;
    }
  }

  /// Execute and store operation for refresh capability
  Future<T> executeAndStore(
    Future<T> Function() operation, {
    bool keepPreviousData = false,
  }) async {
    _lastOperation = operation;
    return execute(operation, keepPreviousData: keepPreviousData);
  }

  /// Refresh the current operation (if any)
  Future<T?> refresh() async {
    if (_lastOperation != null) {
      return execute(_lastOperation!);
    }
    return null;
  }

  /// Cancel the current operation
  void cancel() {
    _operationId++;

    // Restore previous state if we were loading — bypass middleware
    // since this is an internal state restoration, not a user-driven update.
    if (value.isLoading && _stateBeforeLoading != null) {
      setDirect(_stateBeforeLoading!);
      _stateBeforeLoading = null;
    }
  }

  /// Clear the current state back to idle — bypasses middleware since this
  /// is an internal reset, not a user-driven update.
  void clear() {
    _operationId++;
    _stateBeforeLoading = null;
    setDirect(const AsyncValue.idle());
  }

  /// Set data directly (useful for optimistic updates)
  void setData(T data) {
    set(AsyncValue.success(data));
  }

  /// Set error state directly
  void setError(Object error, StackTrace stackTrace) {
    set(AsyncValue.error(error, stackTrace));
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}

/// An atom that bridges an external [Stream] into the atom world.
///
/// Starts in [AsyncState.loading] and transitions to [AsyncState.success] on
/// each emitted event, or [AsyncState.error] on stream errors. When the stream
/// closes normally the atom retains its last state — the data is still valid.
///
/// The subscription is automatically cancelled when the atom is disposed.
///
/// ```dart
/// final positionAtom = StreamAtom(Geolocator.getPositionStream());
///
/// final messagesAtom = StreamAtom(
///   chatSocket.messages,
///   keepPreviousDataOnError: true, // show stale data alongside the error
/// );
/// ```
class StreamAtom<T> extends AsyncAtom<T> {
  StreamSubscription<T>? _subscription;

  StreamAtom(
    Stream<T> stream, {
    super.id,
    super.autoDispose = true,
    super.disposeTimeout,
    bool keepPreviousDataOnError = false,
  }) : super(
          initialValue: const AsyncValue.loading(),
        ) {
    _subscribe(stream, keepPreviousDataOnError: keepPreviousDataOnError);
  }

  void _subscribe(Stream<T> stream, {bool keepPreviousDataOnError = false}) {
    _subscription?.cancel();
    _subscription = stream.listen(
      setData,
      onError: (Object error, StackTrace stackTrace) {
        if (keepPreviousDataOnError) {
          set(AsyncValue.error(error, stackTrace, data: value.data));
        } else {
          setError(error, stackTrace);
        }
      },
      onDone: () => _subscription = null,
    );
  }

  /// Replace the current stream with a new one.
  ///
  /// Cancels the existing subscription and subscribes to [newStream].
  /// Transitions back to [AsyncState.loading] until the first event arrives.
  ///
  /// Useful for reconnecting to a WebSocket or refreshing a live query.
  void reconnect(Stream<T> newStream, {bool keepPreviousDataOnError = false}) {
    if (isDisposed) return;
    set(const AsyncValue.loading());
    _subscribe(newStream, keepPreviousDataOnError: keepPreviousDataOnError);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    super.dispose();
  }
}
