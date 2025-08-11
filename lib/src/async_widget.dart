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

/// Main async builder widget with retry and refresh support
class AsyncBuilder<T> extends StatelessWidget {
  final AsyncAtom<T> atom;
  final Widget Function(BuildContext context, T data) builder;
  final Widget Function(BuildContext context)? loading;
  final Widget Function(BuildContext context, Object error)? error;
  final Widget Function(BuildContext context)? idle;

  // Retry functionality
  final bool enableRetry;
  final Future<T> Function()? retryOperation;
  final Widget Function(BuildContext context, Object error, VoidCallback retry)?
      customRetryError;

  // Refresh functionality
  final bool enableRefresh;
  final Future<T> Function()? onRefresh;

  const AsyncBuilder({
    super.key,
    required this.atom,
    required this.builder,
    this.loading,
    this.error,
    this.idle,
    this.enableRetry = false,
    this.retryOperation,
    this.customRetryError,
    this.enableRefresh = false,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = AtomBuilder<AsyncValue<T>>(
      atom: atom,
      builder: (context, asyncValue) {
        return asyncValue.maybeWhen(
          idle: () => idle?.call(context) ?? const SizedBox.shrink(),
          loading: () =>
              loading?.call(context) ??
              const Center(child: CircularProgressIndicator()),
          success: (data) => builder(context, data),
          error: (err, _) => _buildErrorWidget(context, err),
          orElse: () => const SizedBox.shrink(),
        );
      },
    );

    // Wrap with RefreshIndicator if refresh is enabled
    if (enableRefresh && onRefresh != null) {
      return RefreshIndicator(
        onRefresh: () async {
          await atom.execute(onRefresh!);
        },
        child: content,
      );
    }

    return content;
  }

  Widget _buildErrorWidget(BuildContext context, Object err) {
    // Use custom retry error widget if provided and retry is enabled
    if (enableRetry && retryOperation != null && customRetryError != null) {
      return customRetryError!(
        context,
        err,
        () => atom.execute(retryOperation!),
      );
    }

    // Use default retry error widget if retry is enabled
    if (enableRetry && retryOperation != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $err'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => atom.execute(retryOperation!),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Use custom error widget if provided
    if (error != null) {
      return error!(context, err);
    }

    // Default error widget
    return Center(child: Text('Error: $err'));
  }
}
