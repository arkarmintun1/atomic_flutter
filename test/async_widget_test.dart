import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_flutter/atomic_flutter.dart';

void main() {
  group('AsyncAtomBuilder', () {
    late List<AsyncAtom> atomsToCleanup;

    setUp(() => atomsToCleanup = []);

    tearDown(() {
      for (final atom in atomsToCleanup) {
        atom.dispose();
      }
      atomsToCleanup.clear();
      disableDebugMode();
      AtomDebugger.clearRegistry();
    });

    testWidgets('shows SizedBox.shrink by default in idle state',
        (tester) async {
      final atom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(atom);

      await tester.pumpWidget(MaterialApp(
        home: AsyncAtomBuilder<String>(
          atom: atom,
          builder: (context, data) => Text('Success: $data'),
        ),
      ));

      expect(find.byType(SizedBox), findsWidgets);
      expect(find.text('Success:'), findsNothing);
    });

    testWidgets('shows custom idle widget', (tester) async {
      final atom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(atom);

      await tester.pumpWidget(MaterialApp(
        home: AsyncAtomBuilder<String>(
          atom: atom,
          builder: (ctx, data) => Text('Success: $data'),
          idle: (ctx) => const Text('Tap to load'),
        ),
      ));

      expect(find.text('Tap to load'), findsOneWidget);
    });

    testWidgets('shows CircularProgressIndicator by default while loading',
        (tester) async {
      final atom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(atom);

      await tester.pumpWidget(MaterialApp(
        home: AsyncAtomBuilder<String>(
          atom: atom,
          builder: (ctx, data) => Text('Success: $data'),
        ),
      ));

      atom.execute(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'Result';
      });

      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('shows custom loading widget', (tester) async {
      final atom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(atom);

      await tester.pumpWidget(MaterialApp(
        home: AsyncAtomBuilder<String>(
          atom: atom,
          builder: (ctx, data) => Text('Data: $data'),
          loading: (ctx, prev) => const Text('Custom Loading'),
        ),
      ));

      atom.execute(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        return 'Result';
      });

      await tester.pump();
      expect(find.text('Custom Loading'), findsOneWidget);

      await tester.pumpAndSettle();
    });

    testWidgets('shows previous data in loading callback', (tester) async {
      final atom = AsyncAtom<String>(
        initialValue: AsyncValue.success('Previous'),
        autoDispose: false,
      );
      atomsToCleanup.add(atom);

      await tester.pumpWidget(MaterialApp(
        home: AsyncAtomBuilder<String>(
          atom: atom,
          builder: (ctx, data) => Text('Success: $data'),
          loading: (ctx, prev) => Column(children: [
            const Text('Loading'),
            if (prev != null) Text('Previous: $prev'),
          ]),
        ),
      ));

      final completer = Completer<String>();
      final future = atom.execute(() => completer.future, keepPreviousData: true);

      await tester.pump();
      expect(find.text('Loading'), findsOneWidget);
      expect(find.text('Previous: Previous'), findsOneWidget);

      completer.complete('New');
      await future;
      await tester.pump();

      expect(find.text('Success: New'), findsOneWidget);
    });

    testWidgets('shows builder on success', (tester) async {
      final atom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(atom);

      await tester.pumpWidget(MaterialApp(
        home: AsyncAtomBuilder<String>(
          atom: atom,
          builder: (ctx, data) => Text('Success: $data'),
        ),
      ));

      await atom.execute(() async => 'Result');
      await tester.pump();

      expect(find.text('Success: Result'), findsOneWidget);
    });

    testWidgets('shows default error text without operation', (tester) async {
      final atom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(atom);

      await tester.pumpWidget(MaterialApp(
        home: AsyncAtomBuilder<String>(
          atom: atom,
          builder: (ctx, data) => Text('Data: $data'),
        ),
      ));

      try {
        await atom.execute(() async => throw Exception('oops'));
      } catch (_) {}

      await tester.pump();
      expect(find.text('Error: Exception: oops'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('shows custom error widget', (tester) async {
      final atom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(atom);

      await tester.pumpWidget(MaterialApp(
        home: AsyncAtomBuilder<String>(
          atom: atom,
          builder: (ctx, data) => Text('Data: $data'),
          error: (ctx, e, st, prev) => Text('Custom Error: $e'),
        ),
      ));

      try {
        await atom.execute(() async => throw Exception('oops'));
      } catch (_) {}

      await tester.pump();
      expect(find.text('Custom Error: Exception: oops'), findsOneWidget);
    });

    testWidgets('shows Retry button when operation is provided', (tester) async {
      final atom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(atom);
      bool shouldFail = true;

      Future<String> op() async {
        if (shouldFail) throw Exception('failure');
        return 'recovered';
      }

      await tester.pumpWidget(MaterialApp(
        home: AsyncAtomBuilder<String>(
          atom: atom,
          builder: (ctx, data) => Text('Data: $data'),
          operation: op,
        ),
      ));

      try {
        await atom.execute(op);
      } catch (_) {}

      await tester.pump();
      expect(find.text('Error: Exception: failure'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      shouldFail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Data: recovered'), findsOneWidget);
    });

    testWidgets('operation enables pull-to-refresh', (tester) async {
      final atom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(atom);
      int callCount = 0;

      Future<String> op() async {
        callCount++;
        return 'Refreshed $callCount';
      }

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AsyncAtomBuilder<String>(
            atom: atom,
            builder: (ctx, data) => ListView(
              children: [Text('Data: $data'), const SizedBox(height: 1000)],
            ),
            operation: op,
          ),
        ),
      ));

      await atom.execute(op);
      await tester.pump();
      expect(find.text('Data: Refreshed 1'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, 300));
      await tester.pumpAndSettle();

      expect(callCount, 2);
    });

    testWidgets('no RefreshIndicator when operation is null', (tester) async {
      final atom = AsyncAtom<String>(autoDispose: false);
      atomsToCleanup.add(atom);

      await tester.pumpWidget(MaterialApp(
        home: AsyncAtomBuilder<String>(
          atom: atom,
          builder: (ctx, data) => Text(data),
        ),
      ));

      expect(find.byType(RefreshIndicator), findsNothing);
    });
  });
}
