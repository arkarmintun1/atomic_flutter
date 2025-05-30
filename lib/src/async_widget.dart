import 'package:flutter/material.dart';
import 'async_atom.dart';
import 'widgets.dart';

/// Widget that builds UI based on AsyncAtom state
class AsyncAtomBuilder<T> extends StatelessWidget {
  final AsyncAtom<T> atom;
  final Widget Function(BuildContext context) idle;
  final Widget Function(BuildContext context, T? previousData) loading;
  final Widget Function(BuildContext context, T data) success;
  final Widget Function(BuildContext context, Object error,
      StackTrace stackTrace, T? previousData) error;

  const AsyncAtomBuilder({
    super.key,
    required this.atom,
    required this.idle,
    required this.loading,
    required this.success,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return AtomBuilder<AsyncValue<T>>(
      atom: atom,
      builder: (context, asyncValue) {
        return asyncValue.when(
          idle: () => idle(context),
          loading: () => loading(context, asyncValue.data),
          success: (data) => success(context, data),
          error: (err, stack) => error(context, err, stack, asyncValue.data),
        );
      },
    );
  }
}

/// Simplified async builder with sensible defaults
class SimpleAsyncBuilder<T> extends StatelessWidget {
  final AsyncAtom<T> atom;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loading;
  final Widget Function(BuildContext context, Object error)? error;
  final Widget Function(BuildContext context)? idle;

  const SimpleAsyncBuilder({
    super.key,
    required this.atom,
    required this.builder,
    this.loading,
    this.error,
    this.idle,
  });

  @override
  Widget build(BuildContext context) {
    return AtomBuilder<AsyncValue<T>>(
      atom: atom,
      builder: (context, asyncValue) {
        return asyncValue.maybeWhen(
          idle: () => idle?.call(context) ?? const SizedBox.shrink(),
          loading: () =>
              loading?.call(context) ??
              const Center(child: CircularProgressIndicator()),
          success: (data) => builder(context, data),
          error: (err, _) =>
              error?.call(context, err) ?? Center(child: Text('Error: $err')),
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Widget for handling async operations with retry functionality
class AsyncRetryBuilder<T> extends StatelessWidget {
  final AsyncAtom<T> atom;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loading;
  final Widget Function(BuildContext context, Object error, VoidCallback retry)?
      error;
  final Future<T> Function() operation;

  const AsyncRetryBuilder({
    super.key,
    required this.atom,
    required this.builder,
    required this.operation,
    this.loading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return AtomBuilder<AsyncValue<T>>(
      atom: atom,
      builder: (context, asyncValue) {
        return asyncValue.maybeWhen(
          loading: () =>
              loading?.call(context) ??
              const Center(child: CircularProgressIndicator()),
          success: (data) => builder(context, data),
          error: (err, _) =>
              error?.call(
                context,
                err,
                () => atom.execute(operation),
              ) ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: $err'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => atom.execute(operation),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Widget that handles async operations with pull-to-refresh
class AsyncRefreshBuilder<T> extends StatelessWidget {
  final AsyncAtom<T> atom;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loading;
  final Widget Function(BuildContext context, Object error)? error;
  final Future<T> Function() onRefresh;
  final bool enableRefresh;

  const AsyncRefreshBuilder({
    super.key,
    required this.atom,
    required this.builder,
    required this.onRefresh,
    this.loading,
    this.error,
    this.enableRefresh = true,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = AtomBuilder<AsyncValue<T>>(
      atom: atom,
      builder: (context, asyncValue) {
        return asyncValue.maybeWhen(
          loading: () =>
              loading?.call(context) ??
              const Center(child: CircularProgressIndicator()),
          success: (data) => builder(context, data),
          error: (err, _) =>
              error?.call(context, err) ?? Center(child: Text('Error: $err')),
          orElse: () => const SizedBox.shrink(),
        );
      },
    );

    if (enableRefresh) {
      return RefreshIndicator(
        onRefresh: () async {
          await atom.execute(onRefresh);
        },
        child: content,
      );
    }

    return content;
  }
}
