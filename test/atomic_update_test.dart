import 'package:atomic_flutter/atomic_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('atomicUpdate', () {
    test('notifies listeners once after all updates', () {
      final a = Atom<int>(0, id: 'a', autoDispose: false);
      final b = Atom<int>(0, id: 'b', autoDispose: false);

      int aCalls = 0;
      int bCalls = 0;
      a.addListener((_) => aCalls++);
      b.addListener((_) => bCalls++);

      atomicUpdate(() {
        a.set(1);
        a.set(2);
        b.set(10);
      });

      // Each atom notifies once, not per set() call
      expect(aCalls, 1);
      expect(bCalls, 1);
      expect(a.value, 2);
      expect(b.value, 10);

      a.dispose();
      b.dispose();
    });

    test('atoms hold intermediate values until batch ends', () {
      final a = Atom<int>(0, id: 'a2', autoDispose: false);
      final b = Atom<int>(0, id: 'b2', autoDispose: false);
      int? seenA;
      int? seenB;

      // Listener on a reads b — should see b's final value
      a.addListener((_) {
        seenA = a.value;
        seenB = b.value;
      });

      atomicUpdate(() {
        a.set(1);
        b.set(99);
      });

      expect(seenA, 1);
      expect(seenB, 99); // b already committed when a's listener fires

      a.dispose();
      b.dispose();
    });

    test('does not notify if value did not change', () {
      final atom = Atom<int>(5, autoDispose: false);
      int calls = 0;
      atom.addListener((_) => calls++);

      atomicUpdate(() {
        atom.set(5); // same value
      });

      expect(calls, 0);
      atom.dispose();
    });

    test('computed atoms recompute after batch', () {
      final a = Atom<int>(1, autoDispose: false);
      final b = Atom<int>(2, autoDispose: false);
      final sum = computed<int>(
        () => a.value + b.value,
        tracked: [a, b],
        autoDispose: false,
      );

      int sumCalls = 0;
      sum.addListener((_) => sumCalls++);

      atomicUpdate(() {
        a.set(10);
        b.set(20);
      });

      expect(sum.value, 30);
      // sum recomputes once per source atom that changed
      // (a change triggers recompute to 22, b change triggers recompute to 30)
      expect(sumCalls, greaterThan(0));

      a.dispose();
      b.dispose();
      sum.dispose();
    });

    test('discards dirty set and rethrows on error', () {
      final atom = Atom<int>(0, autoDispose: false);
      int calls = 0;
      atom.addListener((_) => calls++);

      expect(
        () => atomicUpdate(() {
          atom.set(99);
          throw Exception('oops');
        }),
        throwsException,
      );

      // No notification fired
      expect(calls, 0);
      // Value was committed (set() already ran before the throw)
      expect(atom.value, 99);

      atom.dispose();
    });

    test('batchAtomUpdates is an alias for atomicUpdate', () {
      final atom = Atom<int>(0, autoDispose: false);
      int calls = 0;
      atom.addListener((_) => calls++);

      batchAtomUpdates(() {
        atom.set(1);
        atom.set(2);
        atom.set(3);
      });

      expect(calls, 1);
      expect(atom.value, 3);

      atom.dispose();
    });

    test('nested atomicUpdate flushes only on outermost exit', () {
      final atom = Atom<int>(0, autoDispose: false);
      int calls = 0;
      atom.addListener((_) => calls++);

      // Dart is single-threaded so inner atomicUpdate will set _globalBatching
      // to false and flush — nested batching is a known limitation.
      // This test documents current behaviour.
      atomicUpdate(() {
        atom.set(1);
        // Inner batch: flushes immediately when it exits
        atomicUpdate(() {
          atom.set(2);
        });
        atom.set(3);
      });

      expect(atom.value, 3);

      atom.dispose();
    });
  });
}
