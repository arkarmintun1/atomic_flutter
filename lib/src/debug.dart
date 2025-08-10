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

      print('Atom ${atom.id}: $valueString (refs: ${atom.refCount})');
    }

    print('===============================');
  }

  /// Clear all registered atoms
  static void clearRegistry() {
    _debugRegistry.clear();
  }
}

/// Performance monitoring for atoms
class AtomPerformanceMonitor {
  static final Map<String, AtomMetrics> _metrics = {};
  static bool _enabled = false;

  /// Enable performance monitoring
  static void enable() {
    _enabled = true;
  }

  /// Disable performance monitoring
  static void disable() {
    _enabled = false;
    _metrics.clear();
  }

  /// Record an atom update
  static void recordUpdate(String atomId) {
    if (!_enabled) return;

    final metrics = _metrics.putIfAbsent(
      atomId,
      () => AtomMetrics(atomId),
    );
    metrics.recordUpdate();
  }

  /// Get metrics for all atoms
  static Map<String, AtomMetrics> getAllMetrics() {
    return Map.from(_metrics);
  }

  /// Print performance summary
  static void printSummary() {
    if (_metrics.isEmpty) {
      print('No atom metrics available');
      return;
    }

    print('=== AtomicFlutter Performance Summary ===');
    for (final metrics in _metrics.values) {
      print('${metrics.atomId}: ${metrics.updateCount} updates, '
          'avg: ${metrics.averageUpdateInterval.inMilliseconds}ms');
    }
    print('=========================================');
  }
}

/// Metrics for a single atom
class AtomMetrics {
  final String atomId;
  int updateCount = 0;
  DateTime? lastUpdate;
  final List<Duration> _intervals = [];

  AtomMetrics(this.atomId);

  void recordUpdate() {
    final now = DateTime.now();

    if (lastUpdate != null) {
      _intervals.add(now.difference(lastUpdate!));
    }

    updateCount++;
    lastUpdate = now;
  }

  Duration get averageUpdateInterval {
    if (_intervals.isEmpty) return Duration.zero;

    final totalMs =
        _intervals.map((d) => d.inMilliseconds).reduce((a, b) => a + b);

    return Duration(milliseconds: (totalMs / _intervals.length).round());
  }
}

/// Memory usage tracking
class AtomMemoryTracker {
  static bool _enabled = false;
  static final Set<String> _trackedAtoms = {};

  static void enable() {
    _enabled = true;
  }

  static void disable() {
    _enabled = false;
    _trackedAtoms.clear();
  }

  static void trackAtom(String atomId) {
    if (_enabled) {
      _trackedAtoms.add(atomId);
    }
  }

  static void untrackAtom(String atomId) {
    _trackedAtoms.remove(atomId);
  }

  static int get trackedAtomCount => _trackedAtoms.length;

  static void printMemoryUsage() {
    print('=== AtomicFlutter Memory Usage ===');
    print('Tracked atoms: ${_trackedAtoms.length}');
    print('Active atoms: ${AtomDebugger.getAllAtoms().length}');
    print('==================================');
  }
}
