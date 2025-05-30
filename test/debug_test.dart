import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_flutter/atomic_flutter.dart';

void main() {
  group('Debug Tests', () {
    setUp(() {
      // Reset debug state before each test
      disableDebugMode();
      AtomDebugger.clearRegistry();
      AtomPerformanceMonitor.disable();
      AtomMemoryTracker.disable();
    });

    test('should enable and disable debug mode', () {
      expect(Atom.debugMode, false);

      enableDebugMode();
      expect(Atom.debugMode, true);

      disableDebugMode();
      expect(Atom.debugMode, false);
    });

    test('should register atoms in debug mode', () {
      enableDebugMode();

      final atom1 = Atom<int>(1, id: 'test1');
      final atom2 = Atom<String>('test', id: 'test2');

      final allAtoms = AtomDebugger.getAllAtoms();
      expect(allAtoms, hasLength(2));
      expect(allAtoms.any((a) => a.id == 'test1'), true);
      expect(allAtoms.any((a) => a.id == 'test2'), true);
    });

    test('should unregister atoms when disposed', () {
      enableDebugMode();

      final atom = Atom<int>(1, id: 'test');
      expect(AtomDebugger.getAllAtoms(), hasLength(1));

      atom.dispose();
      expect(AtomDebugger.getAllAtoms(), hasLength(0));
    });

    test('should clear debug registry', () {
      enableDebugMode();

      Atom<int>(1, id: 'test1');
      Atom<int>(2, id: 'test2');

      expect(AtomDebugger.getAllAtoms(), hasLength(2));

      AtomDebugger.clearRegistry();
      expect(AtomDebugger.getAllAtoms(), hasLength(0));
    });

    test('should print atom info without throwing', () {
      enableDebugMode();

      Atom<int>(42, id: 'test');
      Atom<String>('hello world', id: 'test2');

      // This test just ensures printAtomInfo doesn't throw
      expect(() => AtomDebugger.printAtomInfo(), returnsNormally);
    });

    test('should truncate long values in debug output', () {
      enableDebugMode();

      final longString = 'a' * 150;
      final atom = Atom<String>(longString, id: 'long');

      // Should not throw even with very long values
      expect(() => AtomDebugger.printAtomInfo(), returnsNormally);
    });

    test('should set default dispose timeout', () {
      final originalTimeout = Atom.defaultDisposeTimeout;

      final newTimeout = Duration(seconds: 30);
      setDefaultDisposeTimeout(newTimeout);

      expect(Atom.defaultDisposeTimeout, newTimeout);

      // Reset to original
      setDefaultDisposeTimeout(originalTimeout);
    });

    test('should not register atoms when debug mode is disabled', () {
      disableDebugMode();

      Atom<int>(1, id: 'test1');
      Atom<int>(2, id: 'test2');

      expect(AtomDebugger.getAllAtoms(), hasLength(0));
    });
  });

  group('Performance Monitor Tests', () {
    test('should enable and disable performance monitoring', () {
      AtomPerformanceMonitor.enable();
      AtomPerformanceMonitor.recordUpdate('test');

      final metrics = AtomPerformanceMonitor.getAllMetrics();
      expect(metrics, isNotEmpty);

      AtomPerformanceMonitor.disable();
      expect(AtomPerformanceMonitor.getAllMetrics(), isEmpty);
    });

    test('should record atom updates', () {
      AtomPerformanceMonitor.enable();

      AtomPerformanceMonitor.recordUpdate('test-atom');
      AtomPerformanceMonitor.recordUpdate('test-atom');
      AtomPerformanceMonitor.recordUpdate('test-atom');

      final metrics = AtomPerformanceMonitor.getAllMetrics();
      expect(metrics['test-atom']?.updateCount, 3);
    });

    test('should calculate average update interval', () async {
      AtomPerformanceMonitor.enable();

      AtomPerformanceMonitor.recordUpdate('test-atom');
      await Future.delayed(Duration(milliseconds: 50));
      AtomPerformanceMonitor.recordUpdate('test-atom');
      await Future.delayed(Duration(milliseconds: 50));
      AtomPerformanceMonitor.recordUpdate('test-atom');

      final metrics = AtomPerformanceMonitor.getAllMetrics();
      final atomMetrics = metrics['test-atom']!;

      expect(atomMetrics.updateCount, 3);
      expect(atomMetrics.averageUpdateInterval.inMilliseconds, greaterThan(40));
      expect(atomMetrics.averageUpdateInterval.inMilliseconds, lessThan(60));
    });

    test('should print performance summary', () {
      AtomPerformanceMonitor.enable();

      AtomPerformanceMonitor.recordUpdate('atom1');
      AtomPerformanceMonitor.recordUpdate('atom2');

      expect(() => AtomPerformanceMonitor.printSummary(), returnsNormally);
    });

    test('should handle empty metrics', () {
      AtomPerformanceMonitor.enable();

      expect(() => AtomPerformanceMonitor.printSummary(), returnsNormally);
    });
  });

  group('Memory Tracker Tests', () {
    test('should enable and disable memory tracking', () {
      AtomMemoryTracker.enable();
      expect(AtomMemoryTracker.trackedAtomCount, 0);

      AtomMemoryTracker.trackAtom('test');
      expect(AtomMemoryTracker.trackedAtomCount, 1);

      AtomMemoryTracker.disable();
      expect(AtomMemoryTracker.trackedAtomCount, 0);
    });

    test('should track and untrack atoms', () {
      AtomMemoryTracker.enable();

      AtomMemoryTracker.trackAtom('atom1');
      AtomMemoryTracker.trackAtom('atom2');
      expect(AtomMemoryTracker.trackedAtomCount, 2);

      AtomMemoryTracker.untrackAtom('atom1');
      expect(AtomMemoryTracker.trackedAtomCount, 1);
    });

    test('should print memory usage', () {
      AtomMemoryTracker.enable();
      enableDebugMode();

      AtomMemoryTracker.trackAtom('test');
      Atom<int>(1, id: 'active');

      expect(() => AtomMemoryTracker.printMemoryUsage(), returnsNormally);
    });

    test('should not track when disabled', () {
      AtomMemoryTracker.disable();

      AtomMemoryTracker.trackAtom('test');
      expect(AtomMemoryTracker.trackedAtomCount, 0);
    });
  });

  group('AtomMetrics Tests', () {
    test('should initialize with correct atom ID', () {
      final metrics = AtomMetrics('test-atom');

      expect(metrics.atomId, 'test-atom');
      expect(metrics.updateCount, 0);
      expect(metrics.lastUpdate, null);
      expect(metrics.averageUpdateInterval, Duration.zero);
    });

    test('should record updates correctly', () async {
      final metrics = AtomMetrics('test-atom');

      metrics.recordUpdate();
      expect(metrics.updateCount, 1);
      expect(metrics.lastUpdate, isNotNull);

      await Future.delayed(Duration(milliseconds: 50));
      metrics.recordUpdate();
      expect(metrics.updateCount, 2);

      expect(metrics.averageUpdateInterval.inMilliseconds, greaterThan(40));
      expect(metrics.averageUpdateInterval.inMilliseconds, lessThan(60));
    });

    test('should handle single update', () {
      final metrics = AtomMetrics('test-atom');

      metrics.recordUpdate();
      expect(metrics.averageUpdateInterval, Duration.zero);
    });
  });
}
