import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_flutter/atomic_flutter.dart';

void main() {
  group('AsyncAtomBuilder Tests', () {
    late List<AsyncAtom> atomsToCleanup;

    setUp(() {
      atomsToCleanup = [];
    });

    tearDown(() {
      // Dispose all atoms created during tests
      for (final atom in atomsToCleanup) {
        atom.dispose();
      }
      atomsToCleanup.clear();

      // Disable debug mode and clear registry
      disableDebugMode();
      AtomDebugger.clearRegistry();
    });

    testWidgets('should show idle state initially', (tester) async {
      final asyncAtom = AsyncAtom<String>(
          autoDispose: false); // Disable auto-dispose in tests
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncAtomBuilder<String>(
            atom: asyncAtom,
            idle: (context) => Text('Idle'),
            loading: (context, previousData) => Text('Loading'),
            success: (context, data) => Text('Success: $data'),
            error: (context, error, stack, previousData) =>
                Text('Error: $error'),
          ),
        ),
      );

      expect(find.text('Idle'), findsOneWidget);
    });

    testWidgets('should show loading state during execution', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncAtomBuilder<String>(
            atom: asyncAtom,
            idle: (context) => Text('Idle'),
            loading: (context, previousData) => Text('Loading'),
            success: (context, data) => Text('Success: $data'),
            error: (context, error, stack, previousData) =>
                Text('Error: $error'),
          ),
        ),
      );

      // Start async operation
      asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 100));
        return 'Result';
      });

      await tester.pump();
      expect(find.text('Loading'), findsOneWidget);

      // Wait for the operation to complete to prevent pending timers
      await tester.pumpAndSettle();
    });

    testWidgets('should show success state after completion', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncAtomBuilder<String>(
            atom: asyncAtom,
            idle: (context) => Text('Idle'),
            loading: (context, previousData) => Text('Loading'),
            success: (context, data) => Text('Success: $data'),
            error: (context, error, stack, previousData) =>
                Text('Error: $error'),
          ),
        ),
      );

      // Execute async operation
      await asyncAtom.execute(() async => 'Result');
      await tester.pump();

      expect(find.text('Success: Result'), findsOneWidget);
    });

    testWidgets('should show error state on failure', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncAtomBuilder<String>(
            atom: asyncAtom,
            idle: (context) => Text('Idle'),
            loading: (context, previousData) => Text('Loading'),
            success: (context, data) => Text('Success: $data'),
            error: (context, error, stack, previousData) =>
                Text('Error: $error'),
          ),
        ),
      );

      // Execute failing async operation
      try {
        await asyncAtom.execute(() async {
          throw Exception('Test error');
        });
      } catch (_) {}

      await tester.pump();

      expect(find.text('Error: Exception: Test error'), findsOneWidget);
    });

    testWidgets('should show previous data during loading', (tester) async {
      final asyncAtom = AsyncAtom<String>(
        initialValue: AsyncValue.success('Previous'),
        autoDispose: false,
      );
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncAtomBuilder<String>(
            atom: asyncAtom,
            idle: (context) => Text('Idle'),
            loading: (context, previousData) => Column(
              children: [
                Text('Loading'),
                if (previousData != null) Text('Previous: $previousData'),
              ],
            ),
            success: (context, data) => Text('Success: $data'),
            error: (context, error, stack, previousData) =>
                Text('Error: $error'),
          ),
        ),
      );

      // Use a Completer to control exactly when the operation completes
      final completer = Completer<String>();

      // Start the operation but don't await it yet
      final future = asyncAtom.execute(
        () => completer.future,
        keepPreviousData: true,
      );

      // Pump once to trigger the loading state
      await tester.pump();

      // Now check the loading state with previous data
      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('Previous: Previous'), findsOneWidget);

      // Complete the async operation
      completer.complete('New');

      // Wait for the operation to finish and UI to update
      await future;
      await tester.pump();

      // Check final state
      expect(find.text('Success: New'), findsOneWidget);
    });
  });

  group('SimpleAsyncBuilder Tests', () {
    late List<AsyncAtom> atomsToCleanup;

    setUp(() {
      atomsToCleanup = [];
    });

    tearDown(() {
      for (final atom in atomsToCleanup) {
        atom.dispose();
      }
      atomsToCleanup.clear();
      disableDebugMode();
      AtomDebugger.clearRegistry();
    });

    testWidgets('should use default loading widget', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: SimpleAsyncBuilder<String>(
            atom: asyncAtom,
            builder: (context, data) => Text('Data: $data'),
          ),
        ),
      );

      // Start async operation
      final future = asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 100));
        return 'Result';
      });

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for completion with timeout
      await future.timeout(Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('should use custom loading widget', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: SimpleAsyncBuilder<String>(
            atom: asyncAtom,
            builder: (context, data) => Text('Data: $data'),
            loading: (context) => Text('Custom Loading'),
          ),
        ),
      );

      // Start async operation
      final future = asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 100));
        return 'Result';
      });

      await tester.pump();
      expect(find.text('Custom Loading'), findsOneWidget);

      await future.timeout(Duration(seconds: 2));
      await tester.pumpAndSettle();
    });

    testWidgets('should show success data', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: SimpleAsyncBuilder<String>(
            atom: asyncAtom,
            builder: (context, data) => Text('Data: $data'),
          ),
        ),
      );

      await asyncAtom.execute(() async => 'Success');
      await tester.pump();

      expect(find.text('Data: Success'), findsOneWidget);
    });

    testWidgets('should use default error widget', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: SimpleAsyncBuilder<String>(
            atom: asyncAtom,
            builder: (context, data) => Text('Data: $data'),
          ),
        ),
      );

      try {
        await asyncAtom.execute(() async {
          throw Exception('Test error');
        });
      } catch (_) {}

      await tester.pump();

      expect(find.text('Error: Exception: Test error'), findsOneWidget);
    });

    testWidgets('should use custom error widget', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: SimpleAsyncBuilder<String>(
            atom: asyncAtom,
            builder: (context, data) => Text('Data: $data'),
            error: (context, error) => Text('Custom Error: $error'),
          ),
        ),
      );

      try {
        await asyncAtom.execute(() async {
          throw Exception('Test error');
        });
      } catch (_) {}

      await tester.pump();

      expect(find.text('Custom Error: Exception: Test error'), findsOneWidget);
    });
  });

  group('AsyncRetryBuilder Tests', () {
    late List<AsyncAtom> atomsToCleanup;

    setUp(() {
      atomsToCleanup = [];
    });

    tearDown(() {
      for (final atom in atomsToCleanup) {
        atom.dispose();
      }
      atomsToCleanup.clear();
      disableDebugMode();
      AtomDebugger.clearRegistry();
    });

    testWidgets('should show retry button on error', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);
      bool shouldFail = true;

      Future<String> operation() async {
        if (shouldFail) {
          throw Exception('Intentional failure');
        }
        return 'Success after retry';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncRetryBuilder<String>(
            atom: asyncAtom,
            operation: operation,
            builder: (context, data) => Text('Data: $data'),
          ),
        ),
      );

      // Execute operation that will fail
      try {
        await asyncAtom.execute(operation);
      } catch (_) {}

      await tester.pump();

      expect(
          find.text('Error: Exception: Intentional failure'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      // Tap retry button
      shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Should show loading initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for completion
      await tester.pumpAndSettle();
    });

    testWidgets('should use custom error widget with retry', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);
      int retryCount = 0;

      Future<String> operation() async {
        throw Exception('Always fails');
      }

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncRetryBuilder<String>(
            atom: asyncAtom,
            operation: operation,
            builder: (context, data) => Text('Data: $data'),
            error: (context, error, retry) => Column(
              children: [
                Text('Custom Error: $error'),
                ElevatedButton(
                  onPressed: () {
                    retryCount++;
                    retry();
                  },
                  child: Text('Custom Retry'),
                ),
              ],
            ),
          ),
        ),
      );

      // Execute failing operation
      try {
        await asyncAtom.execute(operation);
      } catch (_) {}

      await tester.pump();

      expect(
          find.text('Custom Error: Exception: Always fails'), findsOneWidget);
      expect(find.text('Custom Retry'), findsOneWidget);

      // Tap custom retry button
      await tester.tap(find.text('Custom Retry'));
      expect(retryCount, 1);
    });
  });

  group('AsyncRefreshBuilder Tests', () {
    late List<AsyncAtom> atomsToCleanup;

    setUp(() {
      atomsToCleanup = [];
    });

    tearDown(() {
      for (final atom in atomsToCleanup) {
        atom.dispose();
      }
      atomsToCleanup.clear();
      disableDebugMode();
      AtomDebugger.clearRegistry();
    });

    testWidgets('should support pull to refresh', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);
      int refreshCount = 0;

      Future<String> refreshOperation() async {
        refreshCount++;
        return 'Refreshed $refreshCount';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncRefreshBuilder<String>(
            atom: asyncAtom,
            onRefresh: refreshOperation,
            builder: (context, data) => Text('Data: $data'),
          ),
        ),
      );

      // Initial load
      await asyncAtom.execute(refreshOperation);
      await tester.pump();

      expect(find.text('Data: Refreshed 1'), findsOneWidget);

      // Pull to refresh
      await tester.fling(find.byType(RefreshIndicator), Offset(0, 300), 1000);
      await tester.pump();
      await tester.pump(Duration(seconds: 1));

      expect(refreshCount, 2);
    });

    testWidgets('should disable refresh when specified', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncRefreshBuilder<String>(
            atom: asyncAtom,
            onRefresh: () async => 'data',
            enableRefresh: false,
            builder: (context, data) => Text('Data: $data'),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsNothing);
    });
  });
}
