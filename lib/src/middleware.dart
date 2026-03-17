import 'package:atomic_flutter/src/core.dart';

/// Base class for atom middleware.
///
/// Middleware intercepts [Atom.set] calls before the value is stored,
/// allowing you to transform, validate, or observe state changes.
///
/// Override [onSet] to implement your logic. Return [newValue] to allow
/// the change, return [oldValue] to block it, or return a transformed value.
///
/// ```dart
/// class ClampMiddleware extends AtomMiddleware {
///   final int min, max;
///   const ClampMiddleware(this.min, this.max);
///
///   @override
///   T onSet<T>(Atom<T> atom, T oldValue, T newValue) {
///     if (newValue is int) return newValue.clamp(min, max) as T;
///     return newValue;
///   }
/// }
/// ```
///
/// Register globally so it applies to every atom:
/// ```dart
/// Atom.addMiddleware(LoggingMiddleware());
/// ```
///
/// Or pass per-atom transformers directly in the constructor:
/// ```dart
/// final counter = Atom<int>(0, middleware: [(old, next) => next.clamp(0, 100)]);
/// ```
abstract class AtomMiddleware {
  const AtomMiddleware();

  /// Called when [atom].set() is about to store a new value.
  ///
  /// Return [newValue] to proceed, return [oldValue] to block the update,
  /// or return any other value to substitute a different one.
  T onSet<T>(Atom<T> atom, T oldValue, T newValue) => newValue;
}

/// Built-in middleware that prints every atom state change to the console.
///
/// Only active in debug builds (inside an `assert`).
///
/// ```dart
/// Atom.addMiddleware(const LoggingMiddleware());
/// ```
class LoggingMiddleware extends AtomMiddleware {
  const LoggingMiddleware();

  @override
  T onSet<T>(Atom<T> atom, T oldValue, T newValue) {
    assert(() {
      // ignore: avoid_print
      print('[AtomicFlutter] ${atom.id}: $oldValue → $newValue');
      return true;
    }());
    return newValue;
  }
}
