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

  group('AsyncBuilder Tests', () {
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
          home: AsyncBuilder<String>(
            atom: asyncAtom,
            builder: (context, data) => Text('Data: $data'),
          ),
        ),
      );

      // Start async operation
      asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 100));
        return 'Result';
      });

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for completion
      await tester.pumpAndSettle();
      expect(find.text('Data: Result'), findsOneWidget);
    });

    testWidgets('should use custom loading widget', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncBuilder<String>(
            atom: asyncAtom,
            builder: (context, data) => Text('Data: $data'),
            loading: (context) => Text('Custom Loading'),
          ),
        ),
      );

      // Start async operation
      asyncAtom.execute(() async {
        await Future.delayed(Duration(milliseconds: 100));
        return 'Result';
      });

      await tester.pump();
      expect(find.text('Custom Loading'), findsOneWidget);

      // Wait for completion
      await tester.pumpAndSettle();
      expect(find.text('Data: Result'), findsOneWidget);
    });

    testWidgets('should show success data', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncBuilder<String>(
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
          home: AsyncBuilder<String>(
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
          home: AsyncBuilder<String>(
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

  group('AsyncBuilder Retry Tests', () {
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
          home: AsyncBuilder<String>(
            atom: asyncAtom,
            enableRetry: true,
            retryOperation: operation,
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
      
      // Wait for completion and verify success
      await tester.pumpAndSettle();
      expect(find.text('Data: Success after retry'), findsOneWidget);
    });

    testWidgets('should use custom error widget with retry', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);
      int retryCount = 0;
      bool shouldFail = true;

      Future<String> operation() async {
        if (shouldFail && retryCount == 0) {
          throw Exception('Always fails');
        }
        return 'Success after retry';
      }

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncBuilder<String>(
            atom: asyncAtom,
            enableRetry: true,
            retryOperation: operation,
            builder: (context, data) => Text('Data: $data'),
            customRetryError: (context, error, retry) => Column(
              children: [
                Text('Custom Error: $error'),
                ElevatedButton(
                  onPressed: () {
                    retryCount++;
                    shouldFail = false;
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
      await tester.pump();
      
      // Verify retry was called and wait for completion
      expect(retryCount, 1);
      await tester.pumpAndSettle();
      expect(find.text('Data: Success after retry'), findsOneWidget);
    });
  });

  group('AsyncBuilder Refresh Tests', () {
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
          home: Scaffold(
            body: AsyncBuilder<String>(
              atom: asyncAtom,
              enableRefresh: true,
              onRefresh: refreshOperation,
              builder: (context, data) => ListView(
                children: [
                  Text('Data: $data'),
                  // Add some height to make it scrollable
                  const SizedBox(height: 1000),
                ],
              ),
            ),
          ),
        ),
      );

      // Initial load
      await asyncAtom.execute(refreshOperation);
      await tester.pump();

      expect(find.text('Data: Refreshed 1'), findsOneWidget);

      // Pull to refresh using ListView instead of RefreshIndicator
      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(refreshCount, 2);
    });

    testWidgets('should disable refresh when specified', (tester) async {
      final asyncAtom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(asyncAtom);

      await tester.pumpWidget(
        MaterialApp(
          home: AsyncBuilder<String>(
            atom: asyncAtom,
            enableRefresh: false,
            onRefresh: () async => 'data',
            builder: (context, data) => Text('Data: $data'),
          ),
        ),
      );

      expect(find.byType(RefreshIndicator), findsNothing);
    });
  });
}
