import 'package:atomic_flutter/src/core.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Mixin that allows a [State] to reactively watch atoms inside [build].
///
/// Call [watch] for each atom you need — the widget rebuilds whenever any
/// watched atom changes. Subscriptions are reconciled after each frame, so
/// atoms that are no longer watched (e.g. behind a conditional) are
/// automatically unsubscribed.
///
/// ```dart
/// class _MyState extends State<MyWidget> with WatchAtom {
///   @override
///   Widget build(BuildContext context) {
///     final count = watch(counterAtom);
///     final user  = watch(userAtom);
///     return Text('$user: $count');
///   }
/// }
/// ```
///
/// Only call [watch] inside [build]. Calling it in lifecycle methods like
/// [initState] or event handlers has no effect on subscriptions.
mixin WatchAtom<T extends StatefulWidget> on State<T> {
  /// Currently active subscriptions: atom → unsubscribe callback.
  final Map<Atom, VoidCallback> _subscriptions = {};

  /// Atoms accessed during the most-recent (or in-progress) build.
  final Set<Atom> _watching = {};

  bool _reconcileScheduled = false;

  /// Watch [atom] and return its current value.
  ///
  /// Subscribes to [atom] on first call and rebuilds this widget whenever
  /// the atom's value changes. Atoms not watched in a given build are
  /// unsubscribed after the frame completes.
  V watch<V>(Atom<V> atom) {
    _watching.add(atom);

    if (!_subscriptions.containsKey(atom)) {
      void listener(V _) {
        if (mounted) {
          // Clear so the next build starts with a fresh watched set.
          _watching.clear();
          setState(() {});
        }
      }

      atom.addListener(listener);
      _subscriptions[atom] = () => atom.removeListener(listener);
    }

    _scheduleReconcile();
    return atom.value;
  }

  void _scheduleReconcile() {
    if (_reconcileScheduled) return;
    _reconcileScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _reconcileScheduled = false;
      // Remove subscriptions for atoms not watched in the last build.
      final toRemove =
          _subscriptions.keys.where((a) => !_watching.contains(a)).toList();
      for (final atom in toRemove) {
        _subscriptions.remove(atom)?.call();
      }
      _watching.clear();
    });
  }

  @override
  void dispose() {
    for (final unsub in _subscriptions.values) {
      unsub();
    }
    _subscriptions.clear();
    super.dispose();
  }
}
