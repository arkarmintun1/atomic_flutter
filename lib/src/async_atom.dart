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
        return AsyncValue.success(mapper(data!));
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
        return success(data!);
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
        return success?.call(data!) ?? orElse();
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
  Completer<T>? _currentOperation;
  Future<T> Function()? _lastOperation;

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
    // Cancel any ongoing operation
    _currentOperation?.complete();

    final completer = Completer<T>();
    _currentOperation = completer;

    // Set loading state
    final previousData = keepPreviousData ? value.data : null;
    set(AsyncValue.loading(data: previousData));

    try {
      final result = await operation();

      if (_currentOperation == completer && !completer.isCompleted) {
        set(AsyncValue.success(result));
        completer.complete(result);
      }
    } catch (error, stackTrace) {
      if (_currentOperation == completer && !completer.isCompleted) {
        set(AsyncValue.error(error, stackTrace, data: previousData));
        completer.completeError(error, stackTrace);
      }
    }

    return completer.future;
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
    _currentOperation?.complete();
    _currentOperation = null;
  }

  /// Clear the current state back to idle
  void clear() {
    cancel();
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
