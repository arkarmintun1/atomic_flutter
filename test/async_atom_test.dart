import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_flutter/atomic_flutter.dart';

void main() {
  group('AsyncValue Tests', () {
    test('should create idle state', () {
      const asyncValue = AsyncValue<int>.idle();

      expect(asyncValue.isIdle, true);
      expect(asyncValue.isLoading, false);
      expect(asyncValue.hasValue, false);
      expect(asyncValue.hasError, false);
      expect(asyncValue.valueOrNull, null);
    });

    test('should create loading state', () {
      const asyncValue = AsyncValue<int>.loading();

      expect(asyncValue.isLoading, true);
      expect(asyncValue.isIdle, false);
      expect(asyncValue.hasValue, false);
      expect(asyncValue.hasError, false);
    });

    test('should create loading state with previous data', () {
      const asyncValue = AsyncValue<int>.loading(data: 42);

      expect(asyncValue.isLoading, true);
      expect(asyncValue.data, 42);
      expect(asyncValue.valueOrNull, 42);
    });

    test('should create success state', () {
      const asyncValue = AsyncValue<int>.success(42);

      expect(asyncValue.hasValue, true);
      expect(asyncValue.isLoading, false);
      expect(asyncValue.hasError, false);
      expect(asyncValue.value, 42);
      expect(asyncValue.valueOrNull, 42);
    });

    test('should create error state', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;
      final asyncValue = AsyncValue<int>.error(error, stackTrace);

      expect(asyncValue.hasError, true);
      expect(asyncValue.isLoading, false);
      expect(asyncValue.hasValue, false);
      expect(asyncValue.error, error);
      expect(asyncValue.stackTrace, stackTrace);
    });

    test('should throw when accessing value on error state', () {
      final asyncValue =
          AsyncValue<int>.error(Exception('Test'), StackTrace.current);

      expect(() => asyncValue.value, throwsException);
    });

    test('should throw when accessing value on idle state', () {
      const asyncValue = AsyncValue<int>.idle();

      expect(() => asyncValue.value, throwsStateError);
    });

    test('should map values correctly', () {
      const asyncValue = AsyncValue<int>.success(5);
      final mapped = asyncValue.map((value) => value.toString());

      expect(mapped.hasValue, true);
      expect(mapped.value, '5');
    });

    test('should handle errors in map function', () {
      const asyncValue = AsyncValue<int>.success(5);
      final mapped =
          asyncValue.map<String>((value) => throw Exception('Map error'));

      expect(mapped.hasError, true);
      expect(mapped.error.toString(), contains('Map error'));
    });

    test('should handle when pattern matching', () {
      const asyncValue = AsyncValue<int>.success(42);

      final result = asyncValue.when(
        idle: () => 'idle',
        loading: () => 'loading',
        success: (data) => 'success: $data',
        error: (error, stack) => 'error: $error',
      );

      expect(result, 'success: 42');
    });

    test('should handle maybeWhen pattern matching', () {
      const asyncValue = AsyncValue<int>.loading();

      final result = asyncValue.maybeWhen(
        success: (data) => 'success: $data',
        orElse: () => 'other',
      );

      expect(result, 'other');
    });

    test('should implement equality correctly', () {
      const value1 = AsyncValue<int>.success(42);
      const value2 = AsyncValue<int>.success(42);
      const value3 = AsyncValue<int>.success(43);

      expect(value1, equals(value2));
      expect(value1, isNot(equals(value3)));
      expect(value1.hashCode, equals(value2.hashCode));
    });

    test('error states should always compare unequal', () {
      final error = Exception('network timeout');
      final stack = StackTrace.current;
      final value1 = AsyncValue<int>.error(error, stack);
      final value2 = AsyncValue<int>.error(error, stack);

      // Even with same error, they should be unequal so retries trigger rebuilds
      expect(value1, isNot(equals(value2)));
    });

    test('should have proper toString', () {
      const asyncValue = AsyncValue<int>.success(42);
      final string = asyncValue.toString();

      expect(string, contains('AsyncValue'));
      expect(string, contains('success'));
      expect(string, contains('42'));
    });
  });

  group('AsyncAtom Tests', () {
    test('should initialize with idle state', () {
      final asyncAtom = AsyncAtom<int>();

      expect(asyncAtom.value.isIdle, true);
    });

    test('should initialize with custom value', () {
      final asyncAtom = AsyncAtom<int>(
        initialValue: AsyncValue.success(42),
      );

      expect(asyncAtom.value.hasValue, true);
      expect(asyncAtom.value.value, 42);
    });

    test('should notify on repeated identical errors', () {
      final atom = AsyncAtom<String>(autoDispose: false);
      int notifyCount = 0;
      atom.addListener((_) => notifyCount++);

      final error = Exception('network timeout');
      final stack = StackTrace.current;

      atom.setError(error, stack);
      expect(notifyCount, 1);

      // Same error again (e.g. retry failed)
      atom.setError(error, stack);
      expect(notifyCount, 2); // Should still notify
    });

    test('should throw StateError when execute called on disposed atom', () {
      final atom = AsyncAtom<String>(autoDispose: false);
      atom.dispose();

      expect(
        () => atom.execute(() async => 'test'),
        throwsStateError,
      );
    });

    test('should not update state when disposed during async operation',
        () async {
      final atom = AsyncAtom<String>(autoDispose: false);

      final future = atom.execute(() async {
        await Future.delayed(Duration(milliseconds: 20));
        return 'result';
      });

      // Dispose while operation is in flight
      atom.dispose();

      final result = await future;
      expect(result, 'result'); // Future still completes
      expect(atom.value.isLoading, false); // But state was not updated
    });

    test('hasValue should be true for nullable success with null data', () {
      final atom = AsyncAtom<int?>(autoDispose: false);
      atom.setData(null);

      expect(atom.value.hasValue, true);
      expect(atom.value.state, AsyncState.success);
      expect(atom.value.data, isNull);
    });

    test('should execute async operation successfully', () async {
      final asyncAtom = AsyncAtom<String>();

      final result = await asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 10));
        return 'success';
      });

      expect(result, 'success');
      expect(asyncAtom.value.hasValue, true);
      expect(asyncAtom.value.value, 'success');
    });

    test('should handle async operation errors', () async {
      final asyncAtom = AsyncAtom<String>();

      try {
        await asyncAtom.execute(() async {
          await Future.delayed(Duration(milliseconds: 10));
          throw Exception('Test error');
        });
        fail('Should have thrown an exception');
      } on Exception catch (e) {
        expect(e.toString(), contains('Test error'));
      }

      expect(asyncAtom.value.hasError, true);
      expect(asyncAtom.value.error.toString(), contains('Test error'));
    });

    test('should show loading state during execution', () async {
      final asyncAtom = AsyncAtom<String>();
      bool wasLoading = false;

      asyncAtom.addListener((value) {
        if (value.isLoading) {
          wasLoading = true;
        }
      });

      await asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 10));
        return 'done';
      });

      expect(wasLoading, true);
    });

    test('should cancel previous operation when new one starts', () async {
      final asyncAtom = AsyncAtom<String>();

      // Start first operation
      final future1 = asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 50));
        return 'first';
      });

      // Start second operation immediately
      final future2 = asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 10));
        return 'second';
      });

      await Future.wait([future1, future2], eagerError: false);

      expect(asyncAtom.value.value, 'second');
    });

    test('should keep previous data when requested', () async {
      final asyncAtom = AsyncAtom<String>(
        initialValue: AsyncValue.success('initial'),
      );

      bool hadPreviousData = false;

      asyncAtom.addListener((value) {
        if (value.isLoading && value.data == 'initial') {
          hadPreviousData = true;
        }
      });

      await asyncAtom.execute(
        () async {
          await Future.delayed(Duration(milliseconds: 10));
          return 'updated';
        },
        keepPreviousData: true,
      );

      expect(hadPreviousData, true);
      expect(asyncAtom.value.value, 'updated');
    });

    test('should refresh last operation', () async {
      final asyncAtom = AsyncAtom<int>();
      int callCount = 0;

      Future<int> operation() async {
        callCount++;
        return callCount;
      }

      await asyncAtom.executeAndStore(operation);
      expect(asyncAtom.value.value, 1);

      await asyncAtom.refresh();
      expect(asyncAtom.value.value, 2);
    });

    test('should cancel operation', () async {
      final asyncAtom = AsyncAtom<String>();

      // Start operation
      final future = asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 50));
        return 'result';
      });

      // Cancel immediately
      asyncAtom.cancel();

      // Wait for original operation to complete
      await future;

      // State should not be updated to success
      expect(asyncAtom.value.isLoading, false);
    });

    test('should clear state', () {
      final asyncAtom = AsyncAtom<String>(
        initialValue: AsyncValue.success('test'),
      );

      asyncAtom.clear();

      expect(asyncAtom.value.isIdle, true);
    });

    test('should set data directly', () {
      final asyncAtom = AsyncAtom<String>();

      asyncAtom.setData('direct');

      expect(asyncAtom.value.hasValue, true);
      expect(asyncAtom.value.value, 'direct');
    });

    test('should set error directly', () {
      final asyncAtom = AsyncAtom<String>();
      final error = Exception('Direct error');
      final stackTrace = StackTrace.current;

      asyncAtom.setError(error, stackTrace);

      expect(asyncAtom.value.hasError, true);
      expect(asyncAtom.value.error, error);
      expect(asyncAtom.value.stackTrace, stackTrace);
    });

    test('should dispose properly', () {
      final asyncAtom = AsyncAtom<String>();
      bool disposed = false;

      asyncAtom.onDispose(() => disposed = true);
      asyncAtom.dispose();

      expect(disposed, true);
    });

    test('should auto-dispose when enabled', () async {
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
  });

  group('Async Extension Memory Leak Tests', () {
    test('debounceAsync should cleanup when derived atom is disposed', () {
      final source = AsyncAtom<int>(autoDispose: false);
      final derived = source.debounceAsync(Duration(milliseconds: 100));

      // Source should have a listener from derived
      expect(source.refCount, 1);

      derived.dispose();

      // Listener should be removed
      expect(source.refCount, 0);

      source.dispose();
    });

    test('debounceAsync should cleanup when source atom is disposed', () {
      final source = AsyncAtom<int>(autoDispose: false);
      final derived = source.debounceAsync(Duration(milliseconds: 100));

      bool derivedDisposed = false;
      derived.onDispose(() => derivedDisposed = true);

      source.dispose();

      // Derived should be disposed when source is disposed
      expect(derivedDisposed, true);
    });

    test('mapAsync should cleanup when derived atom is disposed', () {
      final source = AsyncAtom<int>(autoDispose: false);
      final derived = source.mapAsync((value) => value.toString());

      expect(source.refCount, 1);

      derived.dispose();
      expect(source.refCount, 0);

      source.dispose();
    });

    test('mapAsync should cleanup when source atom is disposed', () {
      final source = AsyncAtom<int>(autoDispose: false);
      final derived = source.mapAsync((value) => value.toString());

      bool derivedDisposed = false;
      derived.onDispose(() => derivedDisposed = true);

      source.dispose();
      expect(derivedDisposed, true);
    });

    test('chain should cleanup when derived atom is disposed', () async {
      final source = AsyncAtom<int>(autoDispose: false);
      final derived = source.chain((value) async => value.toString());

      expect(source.refCount, 1);

      derived.dispose();
      expect(source.refCount, 0);

      source.dispose();
    });

    test('chain should cleanup when source atom is disposed', () async {
      final source = AsyncAtom<int>(autoDispose: false);
      final derived = source.chain((value) async => value.toString());

      bool derivedDisposed = false;
      derived.onDispose(() => derivedDisposed = true);

      source.dispose();
      expect(derivedDisposed, true);
    });

    test('cached should cleanup when derived atom is disposed', () {
      final source = AsyncAtom<int>(autoDispose: false);
      final derived = source.cached(ttl: Duration(seconds: 5));

      expect(source.refCount, 1);

      derived.dispose();
      expect(source.refCount, 0);

      source.dispose();
    });

    test('cached should cleanup when source atom is disposed', () {
      final source = AsyncAtom<int>(autoDispose: false);
      final derived = source.cached(ttl: Duration(seconds: 5));

      bool derivedDisposed = false;
      derived.onDispose(() => derivedDisposed = true);

      source.dispose();
      expect(derivedDisposed, true);
    });

    test('asyncMap should cleanup when derived atom is disposed', () async {
      final source = Atom<int>(1, autoDispose: false);
      final derived = source.asyncMap((value) async => value.toString());

      expect(source.refCount, greaterThan(0));

      derived.dispose();

      // Wait for async operation to complete
      await Future.delayed(Duration(milliseconds: 10));

      expect(source.refCount, 0);
      source.dispose();
    });

    test('asyncMap should cleanup when source atom is disposed', () async {
      final source = Atom<int>(1, autoDispose: false);
      final derived = source.asyncMap((value) async => value.toString());

      bool derivedDisposed = false;
      derived.onDispose(() => derivedDisposed = true);

      // Wait for initial async operation
      await Future.delayed(Duration(milliseconds: 10));

      source.dispose();
      expect(derivedDisposed, true);
    });

    test('multiple chained extensions should cleanup properly', () async {
      final source = AsyncAtom<int>(autoDispose: false);
      final debounced = source.debounceAsync(Duration(milliseconds: 50));
      final mapped = debounced.mapAsync((value) => value.toString());
      final cached = mapped.cached(ttl: Duration(seconds: 1));

      expect(source.refCount, 1);
      expect(debounced.refCount, 1);
      expect(mapped.refCount, 1);

      // Dispose in reverse order
      cached.dispose();
      expect(mapped.refCount, 0);

      mapped.dispose();
      expect(debounced.refCount, 0);

      debounced.dispose();
      expect(source.refCount, 0);

      source.dispose();
    });

    test('should not leak timers in debounceAsync', () async {
      final source = AsyncAtom<int>(autoDispose: false);
      final derived = source.debounceAsync(Duration(milliseconds: 100));

      // Trigger several updates
      source.setData(1);
      source.setData(2);
      source.setData(3);

      // Dispose before debounce completes
      derived.dispose();

      // Wait to ensure timer doesn't fire
      await Future.delayed(Duration(milliseconds: 150));

      // Should not throw
      source.dispose();
    });

    test('should not leak timers in cached', () async {
      final source = AsyncAtom<int>(autoDispose: false);
      final derived = source.cached(ttl: Duration(milliseconds: 100));

      source.setData(42);

      // Dispose before TTL expires
      derived.dispose();

      // Wait for TTL
      await Future.delayed(Duration(milliseconds: 150));

      // Should not throw
      source.dispose();
    });

    test('computedAsync should cleanup listeners on dispose', () async {
      final a = Atom<int>(1, autoDispose: false);
      final b = Atom<int>(2, autoDispose: false);

      final computed = computedAsync(
        () async => a.value + b.value,
        tracked: [a, b],
        debounce: Duration(milliseconds: 100),
      );

      expect(a.refCount, 1);
      expect(b.refCount, 1);

      computed.dispose();

      // Wait for any pending operations
      await Future.delayed(Duration(milliseconds: 150));

      expect(a.refCount, 0);
      expect(b.refCount, 0);

      a.dispose();
      b.dispose();
    });

    test('combineAsync should cleanup listeners on dispose', () {
      final atom1 = AsyncAtom<int>(autoDispose: false);
      final atom2 = AsyncAtom<int>(autoDispose: false);
      final atom3 = AsyncAtom<int>(autoDispose: false);

      final combined = combineAsync([atom1, atom2, atom3]);

      expect(atom1.refCount, 1);
      expect(atom2.refCount, 1);
      expect(atom3.refCount, 1);

      combined.dispose();

      expect(atom1.refCount, 0);
      expect(atom2.refCount, 0);
      expect(atom3.refCount, 0);

      atom1.dispose();
      atom2.dispose();
      atom3.dispose();
    });
  });

  group('StreamAtom Tests', () {
    test('should start in loading state', () {
      final controller = StreamController<int>();
      final atom = StreamAtom(controller.stream);

      expect(atom.value.isLoading, true);

      atom.dispose();
      controller.close();
    });

    test('should transition to success on first event', () async {
      final controller = StreamController<int>();
      final atom = StreamAtom(controller.stream);

      controller.add(42);
      await Future.delayed(Duration.zero);

      expect(atom.value.hasValue, true);
      expect(atom.value.value, 42);

      atom.dispose();
      controller.close();
    });

    test('should update on subsequent stream events', () async {
      final controller = StreamController<int>();
      final atom = StreamAtom(controller.stream);

      controller.add(1);
      await Future.delayed(Duration.zero);
      expect(atom.value.value, 1);

      controller.add(2);
      await Future.delayed(Duration.zero);
      expect(atom.value.value, 2);

      controller.add(3);
      await Future.delayed(Duration.zero);
      expect(atom.value.value, 3);

      atom.dispose();
      controller.close();
    });

    test('should transition to error on stream error', () async {
      final controller = StreamController<int>();
      final atom = StreamAtom(controller.stream);

      controller.addError(Exception('stream failed'), StackTrace.empty);
      await Future.delayed(Duration.zero);

      expect(atom.value.hasError, true);
      expect(atom.value.error.toString(), contains('stream failed'));

      atom.dispose();
      controller.close();
    });

    test('keepPreviousDataOnError preserves last value alongside error',
        () async {
      final controller = StreamController<int>();
      final atom = StreamAtom(controller.stream, keepPreviousDataOnError: true);

      controller.add(99);
      await Future.delayed(Duration.zero);
      expect(atom.value.value, 99);

      controller.addError(Exception('oops'), StackTrace.empty);
      await Future.delayed(Duration.zero);

      expect(atom.value.hasError, true);
      expect(atom.value.data, 99); // stale data preserved
    });

    test('should retain last state when stream closes normally', () async {
      final controller = StreamController<int>();
      final atom = StreamAtom(controller.stream);

      controller.add(7);
      await Future.delayed(Duration.zero);
      expect(atom.value.value, 7);

      await controller.close();
      await Future.delayed(Duration.zero);

      // State should not reset after stream done
      expect(atom.value.hasValue, true);
      expect(atom.value.value, 7);

      atom.dispose();
    });

    test('should notify listeners when stream emits', () async {
      final controller = StreamController<int>();
      final atom = StreamAtom(controller.stream);
      final received = <int>[];

      atom.addListener((v) {
        if (v.hasValue) received.add(v.value);
      });

      controller.add(10);
      controller.add(20);
      controller.add(30);
      await Future.delayed(Duration.zero);

      expect(received, [10, 20, 30]);

      atom.dispose();
      controller.close();
    });

    test('reconnect replaces stream and resets to loading', () async {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();
      final atom = StreamAtom(controller1.stream);

      controller1.add(1);
      await Future.delayed(Duration.zero);
      expect(atom.value.value, 1);

      atom.reconnect(controller2.stream);
      expect(atom.value.isLoading, true); // reset immediately

      controller2.add(99);
      await Future.delayed(Duration.zero);
      expect(atom.value.value, 99);

      atom.dispose();
      controller1.close();
      controller2.close();
    });

    test('reconnect cancels old subscription', () async {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();
      final atom = StreamAtom(controller1.stream);

      atom.reconnect(controller2.stream);

      // Events from old stream should be ignored
      controller1.add(999);
      await Future.delayed(Duration.zero);
      expect(atom.value.isLoading, true); // still loading, old stream ignored

      controller2.add(1);
      await Future.delayed(Duration.zero);
      expect(atom.value.value, 1);

      atom.dispose();
      controller1.close();
      controller2.close();
    });

    test('should cancel subscription on dispose', () async {
      final controller = StreamController<int>();
      final atom = StreamAtom(controller.stream);

      controller.add(1);
      await Future.delayed(Duration.zero);
      expect(atom.value.value, 1);

      atom.dispose();

      // Adding after dispose should not throw and atom should not update
      expect(() => controller.add(2), returnsNormally);
      controller.close();
    });

    test('should not update state when stream emits after dispose', () async {
      final controller = StreamController<int>();
      final atom = StreamAtom(controller.stream);

      controller.add(1);
      await Future.delayed(Duration.zero);
      expect(atom.value.value, 1);

      atom.dispose();

      // Stream events after disposal should not update atom
      controller.add(42);
      await Future.delayed(Duration.zero);
      expect(atom.value.value, 1); // Unchanged
      expect(atom.isDisposed, true);

      controller.close();
    });

    test('reconnect on disposed atom should be a no-op', () async {
      final controller1 = StreamController<int>();
      final controller2 = StreamController<int>();
      final atom = StreamAtom(controller1.stream);

      atom.dispose();

      // Should not throw or subscribe to new stream
      atom.reconnect(controller2.stream);
      expect(atom.isDisposed, true);

      controller1.close();
      controller2.close();
    });
  });
}
