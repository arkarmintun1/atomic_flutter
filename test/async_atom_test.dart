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
}
