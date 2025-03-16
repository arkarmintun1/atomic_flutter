import 'package:atomic_flutter/atomic_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Counter widget test', (WidgetTester tester) async {
    // Create atom for testing
    final counterAtom = Atom<int>(0);

    // Build widget
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AtomBuilder<int>(
            atom: counterAtom,
            builder: (context, count) {
              return Text('Count: $count', key: Key('countText'));
            },
          ),
        ),
      ),
    );

    // Verify initial state
    expect(find.text('Count: 0'), findsOneWidget);

    // Update atom
    counterAtom.set(5);

    // Wait for widget to rebuild
    await tester.pump();

    // Verify updated state
    expect(find.text('Count: 5'), findsOneWidget);
  });
}
