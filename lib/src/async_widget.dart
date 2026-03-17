import 'package:flutter/material.dart';

import 'async_atom.dart';
import 'widgets.dart';

/// Builds UI from an [AsyncAtom]'s state.
///
/// Only [atom] and [builder] are required. All other states have sensible
/// defaults. Providing [operation] enables both pull-to-refresh and a retry
/// button on the error state — no extra flags needed.
///
/// ```dart
/// // Minimal
/// AsyncAtomBuilder<User>(
///   atom: userAtom,
///   builder: (context, user) => Text(user.name),
/// );
///
/// // Full control
/// AsyncAtomBuilder<User>(
///   atom: userAtom,
///   builder:   (context, user)          => Text(user.name),
///   loading:   (context, prev)          => prev != null
///                                            ? Text(prev.name)
///                                            : const CircularProgressIndicator(),
///   error:     (context, e, st, prev)   => Text('$e'),
///   idle:      (context)                => const Text('Tap to load'),
///   operation: () => api.fetchUser(),   // enables retry + pull-to-refresh
/// );
/// ```
class AsyncAtomBuilder<T> extends StatelessWidget {
  final AsyncAtom<T> atom;

  /// Called when the atom is in the success state.
  final Widget Function(BuildContext context, T data) builder;

  /// Called when loading. Receives the previous value if
  /// [AsyncAtom.execute] was called with `keepPreviousData: true`.
  /// Defaults to a centred [CircularProgressIndicator].
  final Widget Function(BuildContext context, T? previousData)? loading;

  /// Called on error. Receives the error, stack trace, and any previous value.
  /// When [operation] is set and this is null, a default error widget with a
  /// Retry button is shown. Without [operation] a plain error text is shown.
  final Widget Function(
    BuildContext context,
    Object error,
    StackTrace stackTrace,
    T? previousData,
  )? error;

  /// Called when the atom is idle (no operation has run yet).
  /// Defaults to [SizedBox.shrink].
  final Widget Function(BuildContext context)? idle;

  /// When provided, enables pull-to-refresh (via [RefreshIndicator]) and
  /// shows a Retry button on the default error widget.
  final Future<T> Function()? operation;

  const AsyncAtomBuilder({
    super.key,
    required this.atom,
    required this.builder,
    this.loading,
    this.error,
    this.idle,
    this.operation,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = AtomBuilder<AsyncValue<T>>(
      atom: atom,
      builder: (context, asyncValue, _) {
        return asyncValue.when(
          idle: () => idle?.call(context) ?? const SizedBox.shrink(),
          loading: () =>
              loading?.call(context, asyncValue.data) ??
              const Center(child: CircularProgressIndicator()),
          success: (data) => builder(context, data),
          error: (err, stack) =>
              _buildError(context, err, stack, asyncValue.data),
        );
      },
    );

    if (operation != null) {
      return RefreshIndicator(
        onRefresh: () async => atom.execute(operation!),
        child: content,
      );
    }

    return content;
  }

  Widget _buildError(
    BuildContext context,
    Object err,
    StackTrace stack,
    T? prev,
  ) {
    if (error != null) return error!(context, err, stack, prev);

    if (operation != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error: $err'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => atom.execute(operation!),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Center(child: Text('Error: $err'));
  }
}
