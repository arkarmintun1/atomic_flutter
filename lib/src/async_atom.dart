import 'dart:async';
import 'core.dart';

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
  bool get hasValue => state == AsyncState.success && data != null;

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
    if (data == null) {
      throw StateError('AsyncValue has no data');
    }
    return data!;
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
          data == other.data &&
          error == other.error &&
          state == other.state;

  @override
  int get hashCode => Object.hash(data, error, state);

  @override
  String toString() => 'AsyncValue<$T>($state, data: $data, error: $error)';
}

/// An atom that manages async operations and their states
class AsyncAtom<T> extends Atom<AsyncValue<T>> {
  int _operationId = 0;
  Future<T> Function()? _lastOperation;
  AsyncValue<T>? _stateBeforeLoading; // Store state before loading

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

  /// Execute an async operation
  Future<T> execute(
    Future<T> Function() operation, {
    bool keepPreviousData = false,
  }) async {
    // Store current state before setting loading
    _stateBeforeLoading = value;

    // Increment operation ID to cancel previous operations
    final currentOperationId = ++_operationId;

    // Set loading state
    final previousData = keepPreviousData ? value.data : null;
    set(AsyncValue.loading(data: previousData));

    try {
      final result = await operation();

      // Only update state if this is still the current operation
      if (_operationId == currentOperationId) {
        set(AsyncValue.success(result));
        _stateBeforeLoading = null; // Clear stored state
      }

      return result;
    } catch (error, stackTrace) {
      // Only update state if this is still the current operation
      if (_operationId == currentOperationId) {
        set(AsyncValue.error(error, stackTrace, data: previousData));
        _stateBeforeLoading = null; // Clear stored state
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

    // Restore previous state if we were loading
    if (value.isLoading && _stateBeforeLoading != null) {
      set(_stateBeforeLoading!);
      _stateBeforeLoading = null;
    }
  }

  /// Clear the current state back to idle
  void clear() {
    _operationId++;
    _stateBeforeLoading = null;
    set(const AsyncValue.idle());
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
