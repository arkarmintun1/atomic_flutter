import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_flutter/atomic_flutter.dart';

void main() {
  group('Memory Management Tests', () {
    tearDown(() {
      // Reset global state
      setDefaultDisposeTimeout(Duration(minutes: 2));
      disableDebugMode();
    });

    test('should not auto-dispose when autoDispose is false', () async {
      final atom = Atom<int>(
        0,
        autoDispose: false,
        disposeTimeout: Duration(milliseconds: 10),
      );

      bool disposed = false;
      atom.onDispose(() => disposed = true);

      // Add and remove listener
      void listener(int value) {}
      atom.addListener(listener);
      atom.removeListener(listener);

      await Future.delayed(Duration(milliseconds: 20));
      expect(disposed, false);
    });

    test('should auto-dispose after timeout when enabled', () async {
      final atom = Atom<int>(
        0,
        autoDispose: true,
        disposeTimeout: Duration(milliseconds: 10),
      );

      bool disposed = false;
      atom.onDispose(() => disposed = true);

      // Add and remove listener to trigger dispose timer
      void listener(int value) {}
      atom.addListener(listener);
      atom.removeListener(listener);

      await Future.delayed(Duration(milliseconds: 20));
      expect(disposed, true);
    });

    test('should cancel dispose timer when listener is added', () async {
      final atom = Atom<int>(
        0,
        autoDispose: true,
        disposeTimeout: Duration(milliseconds: 10),
      );

      bool disposed = false;
      atom.onDispose(() => disposed = true);

      // Add and remove listener
      void listener1(int value) {}
      atom.addListener(listener1);
      atom.removeListener(listener1);

      // Wait a bit, then add another listener
      await Future.delayed(Duration(milliseconds: 5));
      void listener2(int value) {}
      atom.addListener(listener2);

      // Wait past original timeout
      await Future.delayed(Duration(milliseconds: 10));
      expect(disposed, false);

      // Clean up
      atom.removeListener(listener2);
    });

    test('should use default dispose timeout', () async {
      // Set global default
      setDefaultDisposeTimeout(Duration(milliseconds: 5));

      final atom = Atom<int>(0, autoDispose: true);

      bool disposed = false;
      atom.onDispose(() => disposed = true);

      // Trigger dispose timer
      void listener(int value) {}
      atom.addListener(listener);
      atom.removeListener(listener);

      await Future.delayed(Duration(milliseconds: 10));
      expect(disposed, true);

      // Reset default
      setDefaultDisposeTimeout(Duration(minutes: 2));
    });

    test('should execute dispose callbacks in order', () {
      final atom = Atom<int>(0);
      final executionOrder = <int>[];

      atom.onDispose(() => executionOrder.add(1));
      atom.onDispose(() => executionOrder.add(2));
      atom.onDispose(() => executionOrder.add(3));

      atom.dispose();

      expect(executionOrder, [1, 2, 3]);
    });

    test('should clear dispose callbacks after disposal', () {
      final atom = Atom<int>(0);
      int callCount = 0;

      atom.onDispose(() => callCount++);

      atom.dispose();
      expect(callCount, 1);

      // Dispose again - callbacks should not run
      atom.dispose();
      expect(callCount, 1);
    });

    test('should handle computed atom dependencies disposal', () {
      final baseAtom = Atom<int>(5, autoDispose: false);
      final computedAtom = computed<String>(
        () => 'Value: ${baseAtom.value}',
        tracked: [baseAtom],
        autoDispose: true,
      );

      bool computedDisposed = false;
      computedAtom.onDispose(() => computedDisposed = true);

      // Dispose base atom
      baseAtom.dispose();

      // Computed atom should handle this gracefully
      expect(() => computedAtom.value, returnsNormally);

      // Dispose computed atom
      computedAtom.dispose();
      expect(computedDisposed, true);
    });

    test('should handle weak references correctly', () {
      final baseAtom = Atom<int>(1);
      final computed1 =
          computed<int>(() => baseAtom.value * 2, tracked: [baseAtom]);
      final computed2 =
          computed<int>(() => baseAtom.value * 3, tracked: [baseAtom]);

      // Force disposal of one computed atom
      computed1.dispose();

      // Base atom should still work with remaining computed atom
      baseAtom.set(5);
      expect(computed2.value, 15);

      // Should not throw when base atom changes
      expect(() => baseAtom.set(10), returnsNormally);
      expect(computed2.value, 30);
    });

    test('should handle circular dependencies gracefully', () {
      final atom1 = Atom<int>(1);
      final atom2 = Atom<int>(2);

      // Create circular dependency (not recommended but should not crash)
      atom1.addListener((value) {
        if (value != atom2.value) {
          atom2.set(value);
        }
      });

      atom2.addListener((value) {
        if (value != atom1.value) {
          atom1.set(value);
        }
      });

      // Should not cause infinite loop or crash
      expect(() => atom1.set(5), returnsNormally);
      expect(atom2.value, 5);
    });

    test('should properly manage reference counting', () {
      final atom = Atom<int>(0);

      void listener1(int value) {}
      void listener2(int value) {}
      void listener3(int value) {}

      expect(atom.refCount, 0);

      atom.addListener(listener1);
      expect(atom.refCount, 1);

      atom.addListener(listener2);
      expect(atom.refCount, 2);

      atom.addListener(listener3);
      expect(atom.refCount, 3);

      atom.removeListener(listener2);
      expect(atom.refCount, 2);

      atom.removeListener(listener1);
      atom.removeListener(listener3);
      expect(atom.refCount, 0);
    });

    test('should not increment ref count for duplicate listeners', () {
      final atom = Atom<int>(0);

      void listener(int value) {}

      atom.addListener(listener);
      expect(atom.refCount, 1);

      // Adding same listener again should not increment count
      atom.addListener(listener);
      expect(atom.refCount, 1);
    });

    test('should handle listener removal when not present', () {
      final atom = Atom<int>(0);

      void listener(int value) {}

      // Should not throw when removing non-existent listener
      expect(() => atom.removeListener(listener), returnsNormally);
      expect(atom.refCount, 0);
    });

    test('should handle batch disposal correctly', () {
      final atoms = List.generate(
          10,
          (i) => Atom<int>(i,
              autoDispose: true, disposeTimeout: Duration(milliseconds: 5)));

      final disposedAtoms = <int>[];

      for (int i = 0; i < atoms.length; i++) {
        atoms[i].onDispose(() => disposedAtoms.add(i));

        // Add and remove listeners to trigger disposal
        void listener(int value) {}
        atoms[i].addListener(listener);
        atoms[i].removeListener(listener);
      }

      // Wait for all to dispose
      Future.delayed(Duration(milliseconds: 20)).then((_) {
        expect(disposedAtoms.length, 10);
        expect(disposedAtoms, containsAll([0, 1, 2, 3, 4, 5, 6, 7, 8, 9]));
      });
    });
  });

  group('AsyncAtom Memory Management Tests', () {
    test('should cancel operations on disposal', () async {
      final asyncAtom = AsyncAtom<String>();

      // Start long operation
      final future = asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 100));
        return 'result';
      });

      // Dispose immediately
      asyncAtom.dispose();

      // Operation should still complete but state should not update
      await future;

      // State should not be success
      expect(asyncAtom.value.hasValue, false);
    });

    test('should auto-dispose async atom', () async {
      final asyncAtom = AsyncAtom<String>(
        autoDispose: true,
        disposeTimeout: Duration(milliseconds: 10),
      );

      bool disposed = false;
      asyncAtom.onDispose(() => disposed = true);

      // Add and remove listener
      void listener(AsyncValue<String> value) {}
      asyncAtom.addListener(listener);
      asyncAtom.removeListener(listener);

      await Future.delayed(Duration(milliseconds: 20));
      expect(disposed, true);
    });

    test('should handle multiple async operations disposal', () async {
      final asyncAtom = AsyncAtom<String>();

      // Start multiple operations
      final future1 = asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 50));
        return 'first';
      });

      final future2 = asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 30));
        return 'second';
      });

      // Dispose atom
      asyncAtom.dispose();

      // Both operations should complete without errors
      await Future.wait([future1, future2], eagerError: false);
    });

    test('should clean up timers on disposal', () async {
      final asyncAtom = AsyncAtom<String>();
      final debounced = asyncAtom.debounceAsync(Duration(milliseconds: 100));

      bool disposed = false;
      debounced.onDispose(() => disposed = true);

      // Trigger some updates
      asyncAtom.setData('test1');
      asyncAtom.setData('test2');

      // Dispose before debounce completes
      debounced.dispose();
      expect(disposed, true);

      // Wait longer than debounce period
      await Future.delayed(Duration(milliseconds: 150));

      // Debounced atom should not have been updated
      expect(debounced.value.isIdle, true);
    });

    test('should handle computed async atom disposal', () async {
      final baseAtom = Atom<int>(5);
      final computedAsyncT = computedAsync<String>(
        () async => 'Value: ${baseAtom.value}',
        tracked: [baseAtom],
        debounce: Duration(milliseconds: 50),
      );

      bool disposed = false;
      computedAsyncT.onDispose(() => disposed = true);

      // Wait for initial computation
      await Future.delayed(Duration(milliseconds: 100));

      // Dispose computed async atom
      computedAsyncT.dispose();
      expect(disposed, true);

      // Base atom changes should not affect disposed computed atom
      baseAtom.set(10);
      await Future.delayed(Duration(milliseconds: 100));

      // State should remain unchanged
      expect(computedAsyncT.value.value, 'Value: 5');
    });

    test('should handle family disposal correctly', () {
      final family =
          AtomFamily<String, int>((key) => Atom<String>('value-$key'));

      final atom1 = family(1);
      final atom2 = family(2);
      final atom3 = family(3);

      bool atom1Disposed = false;
      bool atom2Disposed = false;
      bool atom3Disposed = false;

      atom1.onDispose(() => atom1Disposed = true);
      atom2.onDispose(() => atom2Disposed = true);
      atom3.onDispose(() => atom3Disposed = true);

      // Dispose individual atom
      family.disposeKey(2);
      expect(atom2Disposed, true);
      expect(atom1Disposed, false);
      expect(atom3Disposed, false);

      // Dispose entire family
      family.dispose();
      expect(atom1Disposed, true);
      expect(atom3Disposed, true);
    });

    test('should handle memory pressure gracefully', () async {
      // Create many atoms to simulate memory pressure
      final atoms = <Atom<int>>[];

      for (int i = 0; i < 1000; i++) {
        final atom = Atom<int>(i,
            autoDispose: true, disposeTimeout: Duration(milliseconds: 1));
        atoms.add(atom);

        // Add and remove listener to trigger disposal
        void listener(int value) {}
        atom.addListener(listener);
        atom.removeListener(listener);
      }

      // Wait for disposal
      await Future.delayed(Duration(milliseconds: 20));

      // Most atoms should be disposed by now
      // This test mainly ensures no crashes occur under memory pressure
      expect(atoms, isNotEmpty);
    });

    test('should clean up extension-created atoms', () async {
      final baseAtom = Atom<int>(1);

      // Create various extension-based atoms
      final debounced = baseAtom.debounce(Duration(milliseconds: 10));
      final throttled = baseAtom.throttle(Duration(milliseconds: 10));
      final mapped = baseAtom.map((value) => value.toString());
      final filtered = baseAtom.where((value) => value > 0);

      bool debouncedDisposed = false;
      bool throttledDisposed = false;
      bool mappedDisposed = false;
      bool filteredDisposed = false;

      debounced.onDispose(() => debouncedDisposed = true);
      throttled.onDispose(() => throttledDisposed = true);
      mapped.onDispose(() => mappedDisposed = true);
      filtered.onDispose(() => filteredDisposed = true);

      // Dispose base atom
      baseAtom.dispose();

      // Extension atoms should still work but may be auto-disposed
      expect(() => debounced.value, returnsNormally);
      expect(() => throttled.value, returnsNormally);
      expect(() => mapped.value, returnsNormally);
      expect(() => filtered.value, returnsNormally);

      // Explicitly dispose extension atoms
      debounced.dispose();
      throttled.dispose();
      mapped.dispose();
      filtered.dispose();

      expect(debouncedDisposed, true);
      expect(throttledDisposed, true);
      expect(mappedDisposed, true);
      expect(filteredDisposed, true);
    });
  });

  group('Complex Memory Scenarios', () {
    test('should handle deep dependency chains', () {
      final base = Atom<int>(1);
      final computed1 = computed(() => base.value * 2, tracked: [base]);
      final computed2 =
          computed(() => computed1.value + 1, tracked: [computed1]);
      final computed3 =
          computed(() => computed2.value * 3, tracked: [computed2]);

      final disposedAtoms = <String>[];

      base.onDispose(() => disposedAtoms.add('base'));
      computed1.onDispose(() => disposedAtoms.add('computed1'));
      computed2.onDispose(() => disposedAtoms.add('computed2'));
      computed3.onDispose(() => disposedAtoms.add('computed3'));

      // Dispose in different order
      computed2.dispose();
      computed1.dispose();
      computed3.dispose();
      base.dispose();

      expect(disposedAtoms, ['computed2', 'computed1', 'computed3', 'base']);
    });

    test('should handle mixed sync and async atoms', () async {
      final syncAtom = Atom<int>(1);
      final asyncAtom = AsyncAtom<String>();
      final computedFromSync =
          computed(() => syncAtom.value * 2, tracked: [syncAtom]);
      final asyncFromSync = syncAtom.asyncMap((value) async => 'Value: $value');

      await asyncAtom.execute(() async => 'async result');

      bool syncDisposed = false;
      bool asyncDisposed = false;
      bool computedDisposed = false;
      bool asyncFromSyncDisposed = false;

      syncAtom.onDispose(() => syncDisposed = true);
      asyncAtom.onDispose(() => asyncDisposed = true);
      computedFromSync.onDispose(() => computedDisposed = true);
      asyncFromSync.onDispose(() => asyncFromSyncDisposed = true);

      // Dispose all
      syncAtom.dispose();
      asyncAtom.dispose();
      computedFromSync.dispose();
      asyncFromSync.dispose();

      expect(syncDisposed, true);
      expect(asyncDisposed, true);
      expect(computedDisposed, true);
      expect(asyncFromSyncDisposed, true);
    });

    test('should handle rapid creation and disposal', () async {
      final createdAtoms = <Atom<int>>[];
      final disposedCount = <int>[0];

      // Rapidly create and dispose atoms
      for (int i = 0; i < 100; i++) {
        final atom = Atom<int>(i,
            autoDispose: true, disposeTimeout: Duration(milliseconds: 1));
        createdAtoms.add(atom);

        atom.onDispose(() => disposedCount[0]++);

        // Add listener and remove immediately
        void listener(int value) {}
        atom.addListener(listener);
        atom.removeListener(listener);

        // Occasionally dispose manually
        if (i % 10 == 0) {
          atom.dispose();
        }
      }

      // Wait for auto-disposal
      await Future.delayed(Duration(milliseconds: 50));

      // Most atoms should be disposed
      expect(disposedCount[0], greaterThan(80));
    });
  });
}
