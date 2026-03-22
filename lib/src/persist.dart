import 'dart:convert';

import 'package:atomic_flutter/src/core.dart';

/// Storage backend for [persistAtom].
///
/// Implement this to plug in any key-value store:
///
/// ```dart
/// class SharedPreferencesStorage implements AtomStorage {
///   SharedPreferencesStorage(this._prefs);
///   final SharedPreferences _prefs;
///
///   @override
///   Future<String?> read(String key) async => _prefs.getString(key);
///
///   @override
///   Future<void> write(String key, String value) async =>
///       _prefs.setString(key, value);
///
///   @override
///   Future<void> delete(String key) async => _prefs.remove(key);
/// }
/// ```
abstract class AtomStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// In-memory [AtomStorage] — useful for tests and ephemeral state.
class InMemoryAtomStorage implements AtomStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  /// Remove all entries — useful between tests.
  void clear() => _store.clear();
}

/// Creates an [Atom] whose value is persisted in [storage].
///
/// On creation the atom starts with [defaultValue] and immediately begins
/// an async read from [storage]. When the read completes, the atom is
/// updated with the stored value (if any).
///
/// Every subsequent change is written back to [storage] automatically.
///
/// [fromJson] and [toJson] handle serialisation. For primitive types this
/// is trivial:
///
/// ```dart
/// final counterAtom = persistAtom<int>(
///   0,
///   key: 'counter',
///   storage: SharedPreferencesStorage(prefs),
///   fromJson: (v) => (v as num).toInt(),
///   toJson: (v) => v,
/// );
/// ```
///
/// For a custom class:
///
/// ```dart
/// final settingsAtom = persistAtom<Settings>(
///   Settings.defaults(),
///   key: 'settings',
///   storage: SharedPreferencesStorage(prefs),
///   fromJson: (v) => Settings.fromJson(v as Map<String, dynamic>),
///   toJson: (v) => v.toJson(),
/// );
/// ```
Atom<T> persistAtom<T>(
  T defaultValue, {
  required String key,
  required AtomStorage storage,
  required T Function(Object? json) fromJson,
  required Object? Function(T value) toJson,
  bool autoDispose = false,
  bool Function(T, T)? equals,
  String? id,
}) {
  final atom = Atom<T>(
    defaultValue,
    id: id,
    autoDispose: autoDispose,
    equals: equals,
  );

  // Track whether the initial load is still in progress and whether
  // the user has called set() before it completes.
  bool isRestoring = true;
  bool userSetDuringRestore = false;

  // Write back on every change — but skip the write triggered by the
  // initial restore to avoid a redundant round-trip.
  bool skipNextWrite = false;

  void listener(T value) {
    if (skipNextWrite) {
      skipNextWrite = false;
      return;
    }
    if (isRestoring) {
      userSetDuringRestore = true;
    }
    try {
      storage.write(key, jsonEncode(toJson(value)));
    } catch (e) {
      if (Atom.debugMode) {
        print(
          'AtomicFlutter [persistAtom]: Failed to persist "$key": $e',
        );
      }
    }
  }

  atom.addListener(listener);
  atom.onDispose(() => atom.removeListener(listener));

  // Async load: read stored value and update atom if present.
  // If the user called set() before this completes, skip the restore
  // to avoid overwriting the user's value.
  storage.read(key).then((raw) {
    isRestoring = false;
    if (raw == null) return;
    if (userSetDuringRestore) return; // User value takes priority
    if (atom.isDisposed) return;
    try {
      skipNextWrite = true;
      atom.set(fromJson(jsonDecode(raw)));
      // If the value was identical (no change), skipNextWrite was never
      // consumed by the listener, so reset it.
      skipNextWrite = false;
    } catch (e) {
      skipNextWrite = false;
      if (Atom.debugMode) {
        print(
          'AtomicFlutter [persistAtom]: Failed to restore "$key": $e',
        );
      }
    }
  });

  return atom;
}
