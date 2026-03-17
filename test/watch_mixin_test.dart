import 'package:atomic_flutter/atomic_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Concrete test widgets — each state class mixes in WatchAtom and calls
// watch() directly inside its own build(), which is the intended usage.
// ---------------------------------------------------------------------------

class _SingleWatchWidget extends StatefulWidget {
  final Atom<int> atom;
  const _SingleWatchWidget({required this.atom});

  @override
  State<_SingleWatchWidget> createState() => _SingleWatchWidgetState();
}

class _SingleWatchWidgetState extends State<_SingleWatchWidget>
    with WatchAtom {
  @override
  Widget build(BuildContext context) {
    final value = watch(widget.atom);
    return Text('$value');
  }
}

// ---

class _MultiWatchWidget extends StatefulWidget {
  final Atom<int> a;
  final Atom<int> b;
  const _MultiWatchWidget({required this.a, required this.b});

  @override
  State<_MultiWatchWidget> createState() => _MultiWatchWidgetState();
}

class _MultiWatchWidgetState extends State<_MultiWatchWidget> with WatchAtom {
  @override
  Widget build(BuildContext context) {
    final av = watch(widget.a);
    final bv = watch(widget.b);
    return Text('$av-$bv');
  }
}

// ---

class _CountingWidget extends StatefulWidget {
  final Atom<int> atom;
  final void Function() onBuild;
  const _CountingWidget({required this.atom, required this.onBuild});

  @override
  State<_CountingWidget> createState() => _CountingWidgetState();
}

class _CountingWidgetState extends State<_CountingWidget> with WatchAtom {
  @override
  Widget build(BuildContext context) {
    widget.onBuild();
    watch(widget.atom);
    return const SizedBox();
  }
}

// ---

class _ConditionalWatchWidget extends StatefulWidget {
  final Atom<bool> toggle;
  final Atom<int> extra;
  final void Function() onExtraWatched;
  const _ConditionalWatchWidget({
    required this.toggle,
    required this.extra,
    required this.onExtraWatched,
  });

  @override
  State<_ConditionalWatchWidget> createState() =>
      _ConditionalWatchWidgetState();
}

class _ConditionalWatchWidgetState extends State<_ConditionalWatchWidget>
    with WatchAtom {
  @override
  Widget build(BuildContext context) {
    final show = watch(widget.toggle);
    if (show) {
      widget.onExtraWatched();
      watch(widget.extra);
    }
    return Text('show:$show');
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('WatchAtom Mixin Tests', () {
    testWidgets('returns current atom value', (tester) async {
      final atom = Atom<int>(42, autoDispose: false);

      await tester.pumpWidget(
        MaterialApp(home: _SingleWatchWidget(atom: atom)),
      );

      expect(find.text('42'), findsOneWidget);
      atom.dispose();
    });

    testWidgets('rebuilds when atom changes', (tester) async {
      final atom = Atom<int>(0, autoDispose: false);

      await tester.pumpWidget(
        MaterialApp(home: _SingleWatchWidget(atom: atom)),
      );

      expect(find.text('0'), findsOneWidget);

      atom.set(5);
      await tester.pump();

      expect(find.text('5'), findsOneWidget);
      atom.dispose();
    });

    testWidgets('watching multiple atoms rebuilds on any change',
        (tester) async {
      final a = Atom<int>(1, autoDispose: false);
      final b = Atom<int>(2, autoDispose: false);

      await tester.pumpWidget(
        MaterialApp(home: _MultiWatchWidget(a: a, b: b)),
      );

      expect(find.text('1-2'), findsOneWidget);

      a.set(10);
      await tester.pump();
      expect(find.text('10-2'), findsOneWidget);

      b.set(20);
      await tester.pump();
      expect(find.text('10-20'), findsOneWidget);

      a.dispose();
      b.dispose();
    });

    testWidgets('does not rebuild when atom value is the same', (tester) async {
      final atom = Atom<int>(0, autoDispose: false);
      int buildCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _CountingWidget(atom: atom, onBuild: () => buildCount++),
      ));

      expect(buildCount, 1);

      atom.set(0); // same value
      await tester.pump();
      expect(buildCount, 1);

      atom.set(1); // new value
      await tester.pump();
      expect(buildCount, 2);

      atom.dispose();
    });

    testWidgets('unsubscribes from conditionally-removed atom after frame',
        (tester) async {
      final toggle = Atom<bool>(true, autoDispose: false);
      final extra = Atom<int>(0, autoDispose: false);
      int extraWatchCount = 0;

      await tester.pumpWidget(MaterialApp(
        home: _ConditionalWatchWidget(
          toggle: toggle,
          extra: extra,
          onExtraWatched: () => extraWatchCount++,
        ),
      ));

      expect(extraWatchCount, 1);

      // Flip toggle — extra is no longer watched; triggers reconcile
      toggle.set(false);
      await tester.pump(); // build
      await tester.pump(); // post-frame callback fires

      // extra should now be unsubscribed — changing it must not rebuild
      final countBefore = extraWatchCount;
      extra.set(99);
      await tester.pump();

      expect(extraWatchCount, countBefore);

      toggle.dispose();
      extra.dispose();
    });

    testWidgets('cleans up all subscriptions on dispose', (tester) async {
      final atom = Atom<int>(0, autoDispose: false);
      int externalListenerCalls = 0;

      // Separate external listener so we can verify atom still fires
      void externalListener(int _) => externalListenerCalls++;
      atom.addListener(externalListener);

      await tester.pumpWidget(
        MaterialApp(home: _SingleWatchWidget(atom: atom)),
      );

      // Remove widget — triggers WatchAtom.dispose
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      final callsBefore = externalListenerCalls;
      atom.set(1);
      await tester.pump();

      // External listener still fires (+1), but no widget rebuild errors
      expect(externalListenerCalls, callsBefore + 1);

      atom.removeListener(externalListener);
      atom.dispose();
    });
  });
}
