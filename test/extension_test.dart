import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_flutter/atomic_flutter.dart';

void main() {
  group('Atom Extensions Tests', () {
    group('effect', () {
      test('should execute effect immediately with current value', () {
        final atom = Atom<int>(5);
        int? effectValue;

        atom.effect((value) => effectValue = value);

        expect(effectValue, 5);
      });

      test('should execute effect when value changes', () {
        final atom = Atom<int>(0);
        final values = <int>[];

        atom.effect((value) => values.add(value));

        atom.set(1);
        atom.set(2);

        expect(values, [0, 1, 2]); // Initial + 2 changes
      });

      test('should return cleanup function', () {
        final atom = Atom<int>(0);
        final values = <int>[];

        final cleanup = atom.effect((value) => values.add(value));

        atom.set(1);
        cleanup(); // Remove effect
        atom.set(2);

        expect(values, [0, 1]); // Should not include value after cleanup
      });
    });

    group('asStream', () {
      test('should emit current value immediately', () async {
        final atom = Atom<String>('initial');
        final stream = atom.asStream();

        final firstValue = await stream.first;
        expect(firstValue, 'initial');
      });

      test('should emit new values when atom changes', () async {
        final atom = Atom<int>(1);
        final stream = atom.asStream();

        final values = <int>[];
        final subscription = stream.listen(values.add);

        // Wait for initial value to be emitted
        await Future.delayed(Duration(milliseconds: 10));

        atom.set(2);
        atom.set(3);

        await Future.delayed(Duration(milliseconds: 10));

        expect(values, [1, 2, 3]);
        await subscription.cancel();
      });

      test('should handle stream cancellation', () async {
        final atom = Atom<int>(1);
        final stream = atom.asStream();

        final subscription = stream.listen((_) {});
        await subscription.cancel();

        // Should not throw
        atom.set(2);
      });
    });

    group('select', () {
      test('should create AtomSelector widget', () {
        final atom = Atom<Map<String, int>>({'count': 5});

        final widget = atom.select<int>(
          selector: (data) => data['count']!,
          builder: (context, count) => Text('$count'),
        );

        expect(widget, isA<AtomSelector<Map<String, int>, int>>());
      });
    });

    group('debounce', () {
      test('should create debounced atom', () {
        final atom = Atom<String>('initial');
        final debounced = atom.debounce(Duration(milliseconds: 100));

        expect(debounced, isA<Atom<String>>());
        expect(debounced.value, 'initial');
      });

      test('should debounce rapid updates', () async {
        final atom = Atom<int>(0);
        final debounced = atom.debounce(Duration(milliseconds: 50));

        // Rapid updates
        atom.set(1);
        atom.set(2);
        atom.set(3);

        // Should still have initial value
        expect(debounced.value, 0);

        // Wait for debounce
        await Future.delayed(Duration(milliseconds: 100));

        // Should have latest value
        expect(debounced.value, 3);
      });

      test('should auto-dispose debounced atom', () {
        final atom = Atom<int>(0, autoDispose: false);
        final debounced = atom.debounce(Duration(milliseconds: 10));

        expect(debounced.autoDispose, true);
      });
    });

    group('throttle', () {
      test('should create throttled atom', () {
        final atom = Atom<String>('initial');
        final throttled = atom.throttle(Duration(milliseconds: 100));

        expect(throttled, isA<Atom<String>>());
        expect(throttled.value, 'initial');
      });

      test('should throttle rapid updates', () async {
        final atom = Atom<int>(0);
        final throttled = atom.throttle(Duration(milliseconds: 50));
        final values = <int>[];

        throttled.addListener((value) => values.add(value));

        // Rapid updates
        atom.set(1);
        await Future.delayed(Duration(milliseconds: 10));
        atom.set(2);
        await Future.delayed(Duration(milliseconds: 10));
        atom.set(3);

        // Should throttle updates
        expect(values.length, lessThan(3));

        // Wait for throttle period
        await Future.delayed(Duration(milliseconds: 60));
        atom.set(4);

        expect(values, contains(1)); // First update should go through
        expect(values,
            contains(4)); // Update after throttle period should go through
      });
    });

    group('map', () {
      test('should transform atom values', () {
        final atom = Atom<int>(5);
        final mapped = atom.map((value) => value.toString());

        expect(mapped.value, '5');

        atom.set(10);
        expect(mapped.value, '10');
      });

      test('should handle transformation errors gracefully', () {
        enableDebugMode();
        final atom = Atom<int>(5);
        final mapped = atom.map<String>((value) {
          if (value > 10) throw Exception('Too big');
          return value.toString();
        });

        expect(mapped.value, '5');

        // This should not crash the app
        atom.set(15);
        expect(mapped.value, '5'); // Should keep old value

        disableDebugMode();
      });
    });

    group('where', () {
      test('should filter atom values', () {
        final atom = Atom<int>(5);
        final filtered = atom.where((value) => value > 3);
        final values = <int>[];

        filtered.addListener((value) => values.add(value));

        atom.set(2); // Should be filtered out
        atom.set(4); // Should pass
        atom.set(1); // Should be filtered out
        atom.set(6); // Should pass

        expect(values, [4, 6]);
      });
    });

    group('combine', () {
      test('should combine two atoms', () {
        final atom1 = Atom<int>(1);
        final atom2 = Atom<String>('test');
        final combined = atom1.combine(atom2);

        expect(combined.value, (1, 'test'));

        atom1.set(2);
        expect(combined.value, (2, 'test'));

        atom2.set('updated');
        expect(combined.value, (2, 'updated'));
      });
    });

    group('compute', () {
      test('should create computed atom', () {
        final atom = Atom<int>(5);
        final computed = atom.compute((value) => value * 2);

        expect(computed.value, 10);

        atom.set(7);
        expect(computed.value, 14);
      });
    });
  });

  group('Async Extensions Tests', () {
    group('debounceAsync', () {
      test('should create debounced async atom', () {
        final asyncAtom = AsyncAtom<String>();
        final debounced = asyncAtom.debounceAsync(Duration(milliseconds: 100));

        expect(debounced, isA<AsyncAtom<String>>());
      });

      test('should debounce async value updates', () async {
        final asyncAtom = AsyncAtom<String>();
        final debounced = asyncAtom.debounceAsync(Duration(milliseconds: 50));

        // Set multiple values rapidly
        asyncAtom.setData('first');
        asyncAtom.setData('second');
        asyncAtom.setData('third');

        // Should still have initial value
        expect(debounced.value.isIdle, true);

        // Wait for debounce
        await Future.delayed(Duration(milliseconds: 100));

        // Should have latest value
        expect(debounced.value.value, 'third');
      });
    });

    group('mapAsync', () {
      test('should map async atom values', () {
        final asyncAtom = AsyncAtom<int>();
        final mapped = asyncAtom.mapAsync((value) => value.toString());

        asyncAtom.setData(42);

        expect(mapped.value.hasValue, true);
        expect(mapped.value.value, '42');
      });

      test('should handle mapping errors', () {
        final asyncAtom = AsyncAtom<int>();
        final mapped = asyncAtom.mapAsync<String>((value) {
          if (value > 10) throw Exception('Too big');
          return value.toString();
        });

        asyncAtom.setData(5);
        expect(mapped.value.value, '5');

        asyncAtom.setData(15);
        expect(mapped.value.hasError, true);
      });
    });

    group('executeIfNotLoading', () {
      test('should execute if not loading', () async {
        final asyncAtom = AsyncAtom<String>();

        final result =
            await asyncAtom.executeIfNotLoading(() async => 'result');

        expect(result, 'result');
        expect(asyncAtom.value.value, 'result');
      });

      test('should not execute if loading', () async {
        final asyncAtom = AsyncAtom<String>();

        // Start long-running operation
        asyncAtom.execute(() async {
          await Future.delayed(Duration(milliseconds: 100));
          return 'first';
        });

        // Try to execute another operation
        final result =
            await asyncAtom.executeIfNotLoading(() async => 'second');

        expect(result, null);
      });
    });

    group('executeWithRetry', () {
      test('should retry on failure', () async {
        final asyncAtom = AsyncAtom<String>();
        int attempts = 0;

        final result = await asyncAtom.executeWithRetry(
          () async {
            attempts++;
            if (attempts < 3) {
              throw Exception('Attempt $attempts failed');
            }
            return 'Success on attempt $attempts';
          },
          maxRetries: 3,
          delay: Duration(milliseconds: 10),
        );

        expect(result, 'Success on attempt 3');
        expect(attempts, 3);
      });

      test('should give up after max retries', () async {
        final asyncAtom = AsyncAtom<String>();
        int attempts = 0;

        try {
          await asyncAtom.executeWithRetry(
            () async {
              attempts++;
              throw Exception('Always fails');
            },
            maxRetries: 2,
            delay: Duration(milliseconds: 10),
          );
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('Always fails'));
          expect(attempts, 2);
        }
      });
    });

    group('chain', () {
      test('should chain async operations', () async {
        final asyncAtom1 = AsyncAtom<int>();
        final asyncAtom2 = asyncAtom1.chain((value) async => value.toString());

        await asyncAtom1.execute(() async => 42);

        // Wait for chaining to complete
        await Future.delayed(Duration(milliseconds: 10));

        expect(asyncAtom2.value.hasValue, true);
        expect(asyncAtom2.value.value, '42');
      });

      test('should chain errors', () async {
        final asyncAtom1 = AsyncAtom<int>();
        final asyncAtom2 = asyncAtom1.chain((value) async => value.toString());

        try {
          await asyncAtom1.execute(() async => throw Exception('Chain error'));
        } catch (_) {}

        expect(asyncAtom2.value.hasError, true);
      });
    });

    group('cached', () {
      test('should cache successful results', () async {
        final asyncAtom = AsyncAtom<String>();
        final cached = asyncAtom.cached();

        await asyncAtom.execute(() async => 'cached result');

        expect(cached.value.hasValue, true);
        expect(cached.value.value, 'cached result');
      });

      test('should expire cache after TTL', () async {
        final asyncAtom = AsyncAtom<String>();
        final cached = asyncAtom.cached(ttl: Duration(milliseconds: 50));

        await asyncAtom.execute(() async => 'cached result');
        expect(cached.value.hasValue, true);

        // Wait for TTL to expire
        await Future.delayed(Duration(milliseconds: 100));
        expect(cached.value.isIdle, true);
      });
    });

    group('toAsync', () {
      test('should convert regular atom to async atom', () {
        final atom = Atom<int>(42);
        final asyncAtom = atom.toAsync();

        expect(asyncAtom, isA<AsyncAtom<int>>());
        expect(asyncAtom.value.hasValue, true);
        expect(asyncAtom.value.value, 42);
      });

      test('should inherit auto-dispose settings', () {
        final atom = Atom<int>(42,
            autoDispose: false, disposeTimeout: Duration(minutes: 5));
        final asyncAtom = atom.toAsync();

        expect(asyncAtom.autoDispose, false);
        expect(asyncAtom.disposeTimeout, Duration(minutes: 5));
      });
    });

    group('asyncMap', () {
      test('should create async atom that maps values', () async {
        final atom = Atom<int>(5);
        final asyncMapped = atom.asyncMap((value) async => value.toString());

        // Wait for initial execution
        await Future.delayed(Duration(milliseconds: 10));
        expect(asyncMapped.value.value, '5');

        atom.set(10);
        await Future.delayed(Duration(milliseconds: 10));
        expect(asyncMapped.value.value, '10');
      });
    });
  });

  group('computedAsync Tests', () {
    test('should create computed async atom', () {
      final baseAtom = Atom<int>(5);
      final computedAsyncT = computedAsync<String>(
        () async => 'Value: ${baseAtom.value}',
        tracked: [baseAtom],
      );

      expect(computedAsyncT, isA<AsyncAtom<String>>());
    });

    test('should recompute when dependencies change', () async {
      final baseAtom = Atom<int>(5);
      final computedAsyncT = computedAsync<String>(
        () async {
          await Future.delayed(Duration(milliseconds: 10));
          return 'Value: ${baseAtom.value}';
        },
        tracked: [baseAtom],
        debounce: Duration(milliseconds: 50),
      );

      // Wait for initial computation
      await Future.delayed(Duration(milliseconds: 100));
      expect(computedAsyncT.value.value, 'Value: 5');

      // Change dependency
      baseAtom.set(10);

      // Wait for recomputation
      await Future.delayed(Duration(milliseconds: 100));
      expect(computedAsyncT.value.value, 'Value: 10');
    });

    test('should debounce recomputation', () async {
      final baseAtom = Atom<int>(0);
      int computeCount = 0;

      computedAsync<String>(
        () async {
          computeCount++;
          return 'Count: $computeCount';
        },
        tracked: [baseAtom],
        debounce: Duration(milliseconds: 50),
      );

      // Rapid changes
      baseAtom.set(1);
      baseAtom.set(2);
      baseAtom.set(3);

      // Wait for debounce
      await Future.delayed(Duration(milliseconds: 100));

      // Should only compute once due to debouncing (plus initial)
      expect(computeCount, lessThanOrEqualTo(2));
    });
  });

  group('combineAsync Tests', () {
    test('should combine multiple async atoms', () async {
      final atom1 = AsyncAtom<int>();
      final atom2 = AsyncAtom<String>();
      final combined = combineAsync([atom1, atom2]);

      await atom1.execute(() async => 42);
      await atom2.execute(() async => 'test');

      expect(combined.value.hasValue, true);
      expect(combined.value.value, [42, 'test']);
    });

    test('should show loading when any atom is loading', () async {
      final atom1 = AsyncAtom<int>();
      final atom2 = AsyncAtom<String>();
      final combined = combineAsync([atom1, atom2]);

      await atom1.execute(() async => 42);

      // Start loading atom2
      atom2.execute(() async {
        await Future.delayed(Duration(milliseconds: 100));
        return 'test';
      });

      expect(combined.value.isLoading, true);
    });

    test('should show error if any atom has error', () async {
      final atom1 = AsyncAtom<int>();
      final atom2 = AsyncAtom<String>();
      final combined = combineAsync([atom1, atom2]);

      await atom1.execute(() async => 42);

      try {
        await atom2.execute(() async => throw Exception('Test error'));
      } catch (_) {}

      expect(combined.value.hasError, true);
    });
  });

  group('Utility Functions Tests', () {
    test('batchAtomUpdates should work', () {
      final atom1 = Atom<int>(1);
      final atom2 = Atom<int>(2);
      final values = <int>[];

      atom1.addListener((value) => values.add(value));
      atom2.addListener((value) => values.add(value));

      batchAtomUpdates(() {
        atom1.set(10);
        atom2.set(20);
      });

      expect(values, [10, 20]);
    });

    test('createAtoms should create multiple atoms', () {
      final atoms = createAtoms<String>({
        'name': 'John',
        'email': 'john@example.com',
        'city': 'New York',
      });

      expect(atoms.length, 3);
      expect(atoms['name']?.value, 'John');
      expect(atoms['email']?.value, 'john@example.com');
      expect(atoms['city']?.value, 'New York');

      expect(atoms['name']?.id, 'name');
      expect(atoms['email']?.id, 'email');
      expect(atoms['city']?.id, 'city');
    });
  });
}
