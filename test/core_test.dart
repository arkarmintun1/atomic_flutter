import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_flutter/atomic_flutter.dart';

void main() {
  group('Atom Core Tests', () {
    tearDown(() {
      disableDebugMode();
      AtomDebugger.clearRegistry();
    });

    test('should initialize with default value', () {
      final atom = Atom<int>(10);
      expect(atom.value, 10);
    });

    test('should update value using set', () {
      final atom = Atom<String>('initial');
      atom.set('updated');
      expect(atom.value, 'updated');
    });

    test('should update value using update function', () {
      final atom = Atom<int>(5);
      atom.update((current) => current * 2);
      expect(atom.value, 10);
    });

    test('should notify listeners when value changes', () {
      final atom = Atom<int>(0);
      int notificationCount = 0;
      int? lastValue;

      atom.addListener((value) {
        notificationCount++;
        lastValue = value;
      });

      atom.set(5);
      expect(notificationCount, 1);
      expect(lastValue, 5);

      atom.set(10);
      expect(notificationCount, 2);
      expect(lastValue, 10);
    });

    test('should not notify listeners when value is the same', () {
      final atom = Atom<int>(5);
      int notificationCount = 0;

      atom.addListener((value) {
        notificationCount++;
      });

      atom.set(5); // Same value
      expect(notificationCount, 0);
    });

    test('should remove listeners correctly', () {
      final atom = Atom<int>(0);
      int notificationCount = 0;

      void listener(int value) {
        notificationCount++;
      }

      atom.addListener(listener);
      atom.set(1);
      expect(notificationCount, 1);

      atom.removeListener(listener);
      atom.set(2);
      expect(notificationCount, 1); // Should not increase
    });

    test('should handle multiple listeners', () {
      final atom = Atom<int>(0);
      int listener1Count = 0;
      int listener2Count = 0;

      atom.addListener((value) => listener1Count++);
      atom.addListener((value) => listener2Count++);

      atom.set(1);
      expect(listener1Count, 1);
      expect(listener2Count, 1);
    });

    test('should generate unique IDs when not provided', () {
      final atom1 = Atom<int>(1);
      final atom2 = Atom<int>(2);

      expect(atom1.id, isNotNull);
      expect(atom2.id, isNotNull);
      expect(atom1.id, isNot(equals(atom2.id)));
    });

    test('should use provided ID', () {
      final atom = Atom<int>(1, id: 'test-atom');
      expect(atom.id, 'test-atom');
    });

    test('should handle dispose correctly', () {
      final atom = Atom<int>(1);
      int notificationCount = 0;

      atom.addListener((value) => notificationCount++);
      atom.dispose();

      // Should not throw and should not notify after disposal
      expect(() => atom.set(2), returnsNormally);
      expect(notificationCount, 0);
    });

    test('should support onDispose callbacks', () {
      final atom = Atom<int>(1);
      bool disposed = false;

      atom.onDispose(() => disposed = true);
      atom.dispose();

      expect(disposed, true);
    });

    test('should auto-dispose when enabled', () async {
      final atom = Atom<int>(
        1,
        autoDispose: true,
        disposeTimeout: Duration(milliseconds: 10),
      );

      bool disposed = false;
      atom.onDispose(() => disposed = true);

      // Add and remove listener to trigger auto-dispose timer
      void listener(int value) {}
      atom.addListener(listener);
      atom.removeListener(listener);

      // Wait for auto-dispose timeout
      await Future.delayed(Duration(milliseconds: 20));
      expect(disposed, true);
    });

    test('should not auto-dispose when listeners exist', () async {
      final atom = Atom<int>(
        1,
        autoDispose: true,
        disposeTimeout: Duration(milliseconds: 10),
      );

      bool disposed = false;
      atom.onDispose(() => disposed = true);

      atom.addListener((value) {});

      await Future.delayed(Duration(milliseconds: 20));
      expect(disposed, false);
    });

    test('should handle toString correctly', () {
      final atom = Atom<int>(42, id: 'test');
      expect(atom.toString(), contains('42'));
      expect(atom.toString(), contains('test'));
    });

    test('should handle equality and hashCode', () {
      final atom1 = Atom<int>(1, id: 'same');
      final atom2 = Atom<int>(2, id: 'same');
      final atom3 = Atom<int>(1, id: 'different');

      expect(atom1, equals(atom2)); // Same ID
      expect(atom1, isNot(equals(atom3))); // Different ID
      expect(atom1.hashCode, equals(atom2.hashCode));
    });

    test('should track reference count correctly', () {
      final atom = Atom<int>(0);

      expect(atom.refCount, 0);

      void listener1(int value) {}
      void listener2(int value) {}

      atom.addListener(listener1);
      expect(atom.refCount, 1);

      atom.addListener(listener2);
      expect(atom.refCount, 2);

      atom.removeListener(listener1);
      expect(atom.refCount, 1);

      atom.removeListener(listener2);
      expect(atom.refCount, 0);
    });

    test('should handle batch updates', () {
      final atom = Atom<int>(0);
      final values = <int>[];

      atom.addListener((value) => values.add(value));

      atom.batch(() {
        atom.set(1);
        atom.set(2);
        atom.set(3);
      });

      // Should only notify once with final value
      expect(values, [3]);
    });
  });

  group('Computed Atom Tests', () {
    test('should compute initial value', () {
      final baseAtom = Atom<int>(5);
      final computedAtom = computed(() => baseAtom.value * 2);

      expect(computedAtom.value, 10);
    });

    test('should recompute when dependencies change', () {
      final baseAtom = Atom<int>(5);
      final computedAtom =
          computed(() => baseAtom.value * 2, tracked: [baseAtom]);

      baseAtom.set(10);
      expect(computedAtom.value, 20);
    });

    test('should handle multiple dependencies', () {
      final atom1 = Atom<int>(2);
      final atom2 = Atom<int>(3);
      final computedAtom =
          computed(() => atom1.value + atom2.value, tracked: [atom1, atom2]);

      expect(computedAtom.value, 5);

      atom1.set(5);
      expect(computedAtom.value, 8);

      atom2.set(7);
      expect(computedAtom.value, 12);
    });

    test('should notify listeners when recomputed', () {
      final baseAtom = Atom<int>(1);
      final computedAtom =
          computed(() => baseAtom.value * 2, tracked: [baseAtom]);

      int notificationCount = 0;
      computedAtom.addListener((value) => notificationCount++);

      baseAtom.set(2);
      expect(notificationCount, 1);
      expect(computedAtom.value, 4);
    });

    test('should handle nested computed atoms', () {
      final baseAtom = Atom<int>(2);
      final computed1 = computed(() => baseAtom.value * 2, tracked: [baseAtom]);
      final computed2 =
          computed(() => computed1.value + 1, tracked: [computed1]);

      expect(computed2.value, 5); // (2 * 2) + 1 = 5

      baseAtom.set(3);
      expect(computed2.value, 7); // (3 * 2) + 1 = 7
    });

    test('should dispose computed atom properly', () {
      final baseAtom = Atom<int>(1);
      final computedAtom =
          computed(() => baseAtom.value * 2, tracked: [baseAtom]);

      computedAtom.dispose();

      // Should not throw
      baseAtom.set(5);
      expect(() => computedAtom.value, returnsNormally);
    });
  });

  group('AtomFamily Tests', () {
    test('should create atoms with different keys', () {
      final family =
          AtomFamily<String, int>((key) => Atom<String>('value-$key'));

      final atom1 = family(1);
      final atom2 = family(2);

      expect(atom1.value, 'value-1');
      expect(atom2.value, 'value-2');
      expect(atom1, isNot(same(atom2)));
    });

    test('should return same atom for same key', () {
      final family =
          AtomFamily<String, int>((key) => Atom<String>('value-$key'));

      final atom1 = family(1);
      final atom2 = family(1);

      expect(atom1, same(atom2));
    });

    test('should dispose family atoms', () {
      final family =
          AtomFamily<String, int>((key) => Atom<String>('value-$key'));

      final atom1 = family(1);
      final atom2 = family(2);

      bool atom1Disposed = false;
      bool atom2Disposed = false;

      atom1.onDispose(() => atom1Disposed = true);
      atom2.onDispose(() => atom2Disposed = true);

      family.dispose();

      expect(atom1Disposed, true);
      expect(atom2Disposed, true);
    });

    test('should dispose individual family atoms', () {
      final family =
          AtomFamily<String, int>((key) => Atom<String>('value-$key'));

      final atom1 = family(1);
      bool disposed = false;
      atom1.onDispose(() => disposed = true);

      family.disposeKey(1);
      expect(disposed, true);

      // Should create new atom for same key
      final atom2 = family(1);
      expect(atom2, isNot(same(atom1)));
    });
  });
}
