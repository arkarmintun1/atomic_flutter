import 'core.dart';

/// Enable debug mode to see atom operations in console
///
/// When debug mode is enabled, AtomicFlutter will print information
/// about atom creation, updates, and disposal to the console.
void enableDebugMode() {
  Atom.debugMode = true;
}

/// Disable debug mode
void disableDebugMode() {
  Atom.debugMode = false;
}

/// Set the default auto-dispose timeout for atoms
///
/// This is how long an atom will wait before being disposed
/// after all listeners have been removed.
///
/// The default is 2 minutes.
void setDefaultDisposeTimeout(Duration timeout) {
  Atom.defaultDisposeTimeout = timeout;
}

/// Debugging utilities for AtomicFlutter
class AtomDebugger {
  /// Registry of atoms for debugging
  static final Map<String, Atom> _debugRegistry = {};

  /// Register an atom for debugging
  static void register(Atom atom) {
    _debugRegistry[atom.id] = atom;
  }

  /// Unregister an atom
  static void unregister(Atom atom) {
    _debugRegistry.remove(atom.id);
  }

  /// Get all registered atoms
  static List<Atom> getAllAtoms() {
    return _debugRegistry.values.toList();
  }

  /// Print information about all registered atoms
  static void printAtomInfo() {
    print('=== AtomicFlutter Debug Info ===');
    print('Total atoms: ${_debugRegistry.length}');

    for (final atom in _debugRegistry.values) {
      final value = atom.value;
      final valueString = value.toString().length > 100
          ? '${value.toString().substring(0, 100)}...'
          : value.toString();

      print('Atom ${atom.id}: $valueString');
    }

    print('===============================');
  }

  /// Clear all registered atoms
  static void clearRegistry() {
    _debugRegistry.clear();
  }
}
