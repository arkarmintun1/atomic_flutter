import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atomic_flutter/atomic_flutter.dart';

void main() {
  group('AtomBuilder Tests', () {
    testWidgets('should build with initial value', (tester) async {
      final atom = Atom<int>(
        42,
        autoDispose: false, // Disable auto-dispose for tests
      );

      await tester.pumpWidget(
        MaterialApp(
          home: AtomBuilder<int>(
            atom: atom,
            builder: (context, value) => Text('Value: $value'),
          ),
        ),
      );

      expect(find.text('Value: 42'), findsOneWidget);

      // Clean up
      atom.dispose();
    });

    testWidgets('should rebuild when atom changes', (tester) async {
      final atom = Atom<int>(
        0, autoDispose: false, // Disable auto-dispose for tests
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AtomBuilder<int>(
                  atom: atom,
                  builder: (context, value) => Text('Count: $value'),
                ),
                ElevatedButton(
                  onPressed: () => atom.update((v) => v + 1),
                  child: Text('Increment'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Count: 0'), findsOneWidget);

      await tester.tap(find.text('Increment'));
      await tester.pump();

      expect(find.text('Count: 1'), findsOneWidget);
      expect(find.text('Count: 0'), findsNothing);

      // Clean up
      atom.dispose();
    });

    testWidgets('should not rebuild when atom value is the same',
        (tester) async {
      final atom = Atom<int>(5, autoDispose: false);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AtomBuilder<int>(
            atom: atom,
            builder: (context, value) {
              buildCount++;
              return Text('Value: $value');
            },
          ),
        ),
      );

      expect(buildCount, 1);

      // Set same value
      atom.set(5);
      await tester.pump();

      expect(buildCount, 1); // Should not rebuild

      // Clean up
      atom.dispose();
    });

    testWidgets('should handle multiple AtomBuilders', (tester) async {
      final atom = Atom<int>(10, autoDispose: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Column(
            children: [
              AtomBuilder<int>(
                atom: atom,
                builder: (context, value) => Text('First: $value'),
              ),
              AtomBuilder<int>(
                atom: atom,
                builder: (context, value) => Text('Second: ${value * 2}'),
              ),
            ],
          ),
        ),
      );

      expect(find.text('First: 10'), findsOneWidget);
      expect(find.text('Second: 20'), findsOneWidget);

      atom.set(5);
      await tester.pump();

      expect(find.text('First: 5'), findsOneWidget);
      expect(find.text('Second: 10'), findsOneWidget);

      // Clean up
      atom.dispose();
    });

    testWidgets('should dispose listener when widget is disposed',
        (tester) async {
      final atom = Atom<int>(0, autoDispose: false);

      await tester.pumpWidget(
        MaterialApp(
          home: AtomBuilder<int>(
            atom: atom,
            builder: (context, value) => Text('$value'),
          ),
        ),
      );

      // Widget should be listening
      expect(atom.hasListeners, true);

      // Remove widget
      await tester.pumpWidget(Container());

      // Should no longer be listening
      expect(atom.hasListeners, false);

      // Clean up
      atom.dispose();
    });
  });

  group('AtomConsumer Tests', () {
    testWidgets('should provide atom value to builder', (tester) async {
      final atom = Atom<String>('test', autoDispose: false);

      await tester.pumpWidget(
        MaterialApp(
          home: AtomConsumer<String>(
            atom: atom,
            builder: (context, value, child) {
              return Column(
                children: [
                  Text('Value: $value'),
                  child!,
                ],
              );
            },
            child: Text('Static child'),
          ),
        ),
      );

      expect(find.text('Value: test'), findsOneWidget);
      expect(find.text('Static child'), findsOneWidget);

      // Clean up
      atom.dispose();
    });

    testWidgets('should not rebuild child when atom changes', (tester) async {
      final atom = Atom<int>(1, autoDispose: false);
      int childBuildCount = 0;

      Widget buildChild() {
        childBuildCount++;
        return Text('Child built $childBuildCount times');
      }

      await tester.pumpWidget(
        MaterialApp(
          home: AtomConsumer<int>(
            atom: atom,
            builder: (context, value, child) {
              return Column(
                children: [
                  Text('Value: $value'),
                  child!,
                ],
              );
            },
            child: buildChild(),
          ),
        ),
      );

      expect(childBuildCount, 1);

      atom.set(2);
      await tester.pump();

      expect(find.text('Value: 2'), findsOneWidget);
      expect(childBuildCount, 1); // Child should not rebuild

      // Clean up
      atom.dispose();
    });
  });

  group('AtomSelector Tests', () {
    testWidgets('should select and build with selected value', (tester) async {
      final atom =
          Atom<Map<String, int>>({'count': 5, 'other': 10}, autoDispose: false);

      await tester.pumpWidget(
        MaterialApp(
          home: AtomSelector<Map<String, int>, int>(
            atom: atom,
            selector: (data) => data['count']!,
            builder: (context, count) => Text('Count: $count'),
          ),
        ),
      );

      expect(find.text('Count: 5'), findsOneWidget);

      // Clean up
      atom.dispose();
    });

    testWidgets('should only rebuild when selected value changes',
        (tester) async {
      final atom =
          Atom<Map<String, int>>({'count': 5, 'other': 10}, autoDispose: false);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: AtomSelector<Map<String, int>, int>(
            atom: atom,
            selector: (data) => data['count']!,
            builder: (context, count) {
              buildCount++;
              return Text('Count: $count');
            },
          ),
        ),
      );

      expect(buildCount, 1);

      // Change non-selected value
      atom.update((data) => {...data, 'other': 20});
      await tester.pump();

      expect(buildCount, 1); // Should not rebuild

      // Change selected value
      atom.update((data) => {...data, 'count': 7});
      await tester.pump();

      expect(buildCount, 2); // Should rebuild
      expect(find.text('Count: 7'), findsOneWidget);

      // Clean up
      atom.dispose();
    });
  });

  group('MultiAtomBuilder Tests', () {
    testWidgets('should rebuild when any atom changes', (tester) async {
      final atom1 = Atom<int>(1, autoDispose: false);
      final atom2 = Atom<String>('test', autoDispose: false);
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: MultiAtomBuilder(
            atoms: [atom1, atom2],
            builder: (context) {
              buildCount++;
              return Text('${atom1.value} - ${atom2.value}');
            },
          ),
        ),
      );

      expect(buildCount, 1);
      expect(find.text('1 - test'), findsOneWidget);

      atom1.set(2);
      await tester.pump();

      expect(buildCount, 2);
      expect(find.text('2 - test'), findsOneWidget);

      atom2.set('updated');
      await tester.pump();

      expect(buildCount, 3);
      expect(find.text('2 - updated'), findsOneWidget);

      // Clean up
      atom1.dispose();
      atom2.dispose();
    });

    testWidgets('should handle atom list changes', (tester) async {
      final atom1 = Atom<int>(1, autoDispose: false);
      final atom2 = Atom<int>(2, autoDispose: false);
      final atom3 = Atom<int>(3, autoDispose: false);

      await tester.pumpWidget(
        MaterialApp(
          home: MultiAtomBuilder(
            atoms: [atom1, atom2],
            builder: (context) => Text('${atom1.value} - ${atom2.value}'),
          ),
        ),
      );

      expect(find.text('1 - 2'), findsOneWidget);

      // Update widget with different atoms
      await tester.pumpWidget(
        MaterialApp(
          home: MultiAtomBuilder(
            atoms: [atom1, atom3],
            builder: (context) => Text('${atom1.value} - ${atom3.value}'),
          ),
        ),
      );

      expect(find.text('1 - 3'), findsOneWidget);

      // atom2 changes should not trigger rebuild anymore
      atom2.set(99);
      await tester.pump();

      expect(find.text('1 - 3'), findsOneWidget);

      // atom3 changes should trigger rebuild
      atom3.set(30);
      await tester.pump();

      expect(find.text('1 - 30'), findsOneWidget);

      // Clean up
      atom1.dispose();
      atom2.dispose();
      atom3.dispose();
    });
  });
}
