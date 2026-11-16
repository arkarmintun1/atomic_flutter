// Regression tests for the fixes shipped in 0.5.2.
//
// Each group targets one bug found in the v0.5.1 review. Most tests fail
// (or report an unhandled error) against 0.5.1; a few pin down behaviour
// that must keep working alongside the fix.
import 'package:atomic_flutter/atomic_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _flushMicrotasks() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _ListenerOwner {
  int calls = 0;
  void onValue(int _) => calls++;
}

class _FailingStorage implements AtomStorage {
  @override
  Future<String?> read(String key) => Future.error(StateError('read failed'));

  @override
  Future<void> write(String key, String value) =>
      Future.error(StateError('write failed'));

  @override
  Future<void> delete(String key) async {}
}

class _WatchBoth extends StatefulWidget {
  const _WatchBoth(this.a, this.b);
  final Atom<int> a;
  final Atom<int> b;

  @override
  State<_WatchBoth> createState() => _WatchBothState();
}

class _WatchBothState extends State<_WatchBoth> with WatchAtom {
  @override
  Widget build(BuildContext context) {
    final a = watch(widget.a);
    final b = watch(widget.b);
    return Text('$a-$b', textDirection: TextDirection.ltr);
  }
}

class _IndexedSelector extends StatelessWidget {
  const _IndexedSelector(this.atom, this.index);
  final Atom<List<String>> atom;
  final int index;

  @override
  Widget build(BuildContext context) {
    return AtomSelector<List<String>, String>(
      atom: atom,
      selector: (list) => list[index],
      builder: (context, item) =>
          Text(item, textDirection: TextDirection.ltr),
    );
  }
}

void main() {
  group('Listener removal with method tear-offs', () {
    test('removeListener works with an instance-method tear-off', () {
      final atom = Atom<int>(0, autoDispose: false);
      final owner = _ListenerOwner();

      atom.addListener(owner.onValue);
      expect(atom.hasListeners, isTrue);

      // A fresh tear-off: == to the first one, but not identical.
      atom.removeListener(owner.onValue);
      expect(atom.hasListeners, isFalse);
      expect(atom.refCount, 0);

      atom.set(1);
      expect(owner.calls, 0);
    });

    test('adding the same tear-off twice registers it once', () {
      final atom = Atom<int>(0, autoDispose: false);
      final owner = _ListenerOwner();

      atom.addListener(owner.onValue);
      atom.addListener(owner.onValue);
      expect(atom.refCount, 1);

      atom.set(1);
      expect(owner.calls, 1);
    });

    testWidgets('AtomBuilder unsubscribes on unmount', (tester) async {
      final atom = Atom<int>(0, autoDispose: false);

      await tester.pumpWidget(AtomBuilder<int>(
        atom: atom,
        builder: (_, v, __) => Text('$v', textDirection: TextDirection.ltr),
      ));
      expect(atom.hasListeners, isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(atom.hasListeners, isFalse);
      expect(atom.refCount, 0);
    });

    testWidgets('AtomSelector unsubscribes on unmount', (tester) async {
      final atom = Atom<int>(0, autoDispose: false);

      await tester.pumpWidget(AtomSelector<int, bool>(
        atom: atom,
        selector: (v) => v.isEven,
        builder: (_, even) => Text('$even', textDirection: TextDirection.ltr),
      ));
      expect(atom.hasListeners, isTrue);

      await tester.pumpWidget(const SizedBox());
      expect(atom.hasListeners, isFalse);
    });

    testWidgets('auto-dispose fires after the last AtomBuilder unmounts',
        (tester) async {
      final atom = Atom<int>(0, disposeTimeout: const Duration(seconds: 1));

      await tester.pumpWidget(AtomBuilder<int>(
        atom: atom,
        builder: (_, v, __) => Text('$v', textDirection: TextDirection.ltr),
      ));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));

      expect(atom.isDisposed, isTrue);
    });

    test('AtomHistory.dispose detaches from the source atom', () {
      final atom = Atom<int>(0, autoDispose: false);
      final history = AtomHistory(atom);
      expect(atom.hasListeners, isTrue);

      history.dispose();
      expect(atom.hasListeners, isFalse);
    });
  });

  group('Async errors are captured, not left unhandled', () {
    test('asyncMap', () async {
      final source = Atom<int>(1, autoDispose: false);
      final mapped = source.asyncMap<int>((v) async => throw StateError('$v'));

      await _flushMicrotasks();
      expect(mapped.value.hasError, isTrue);

      source.set(2);
      await _flushMicrotasks();
      expect(mapped.value.hasError, isTrue);
    });

    test('chain', () async {
      final source = AsyncAtom<int>(autoDispose: false);
      final chained =
          source.chain<int>((v) async => throw StateError('chain $v'));

      source.setData(1);
      await _flushMicrotasks();
      expect(chained.value.hasError, isTrue);
    });

    test('computedAsync', () async {
      final dep = Atom<int>(1, autoDispose: false);
      final result = computedAsync<int>(
        () async => throw StateError('compute'),
        tracked: [dep],
        debounce: Duration.zero,
      );

      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(result.value.hasError, isTrue);
    });

    test('persistAtom with failing storage keeps working', () async {
      final atom = persistAtom<int>(
        7,
        key: 'k',
        storage: _FailingStorage(),
        fromJson: (v) => (v as num).toInt(),
        toJson: (v) => v,
      );

      await _flushMicrotasks();
      expect(atom.value, 7);

      atom.set(8);
      await _flushMicrotasks();
      expect(atom.value, 8);
    });

    testWidgets('AsyncAtomBuilder retry button', (tester) async {
      final atom = AsyncAtom<int>(
        initialValue: AsyncValue.error(StateError('first'), StackTrace.empty),
        autoDispose: false,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AsyncAtomBuilder<int>(
            atom: atom,
            builder: (_, v) => Text('$v'),
            operation: () async => throw StateError('again'),
          ),
        ),
      ));

      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump();

      expect(atom.value.hasError, isTrue);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('Atoms sharing an id are still distinct subscriptions', () {
    testWidgets('AtomBuilder resubscribes when swapped to a same-id atom',
        (tester) async {
      final a = Atom<int>(1, id: 'shared', autoDispose: false);
      final b = Atom<int>(2, id: 'shared', autoDispose: false);

      Widget build(Atom<int> atom) => AtomBuilder<int>(
            atom: atom,
            builder: (_, v, __) =>
                Text('$v', textDirection: TextDirection.ltr),
          );

      await tester.pumpWidget(build(a));
      expect(find.text('1'), findsOneWidget);

      await tester.pumpWidget(build(b));
      expect(find.text('2'), findsOneWidget);
      expect(a.hasListeners, isFalse);
      expect(b.hasListeners, isTrue);

      b.set(3);
      await tester.pump();
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('MultiAtomBuilder listens to every same-id atom',
        (tester) async {
      final a = Atom<int>(1, id: 'shared', autoDispose: false);
      final b = Atom<int>(2, id: 'shared', autoDispose: false);

      await tester.pumpWidget(MultiAtomBuilder(
        atoms: [a, b],
        builder: (_) =>
            Text('${a.value}-${b.value}', textDirection: TextDirection.ltr),
      ));

      b.set(5);
      await tester.pump();
      expect(find.text('1-5'), findsOneWidget);
    });

    testWidgets('WatchAtom subscribes to every same-id atom', (tester) async {
      final a = Atom<int>(1, id: 'shared', autoDispose: false);
      final b = Atom<int>(2, id: 'shared', autoDispose: false);

      await tester.pumpWidget(_WatchBoth(a, b));
      expect(find.text('1-2'), findsOneWidget);

      b.set(9);
      await tester.pump();
      expect(find.text('1-9'), findsOneWidget);
    });

    test('atomicUpdate flushes every same-id atom', () {
      final a = Atom<int>(0, id: 'shared', autoDispose: false);
      final b = Atom<int>(0, id: 'shared', autoDispose: false);
      final seen = <String>[];
      a.addListener((v) => seen.add('a$v'));
      b.addListener((v) => seen.add('b$v'));

      atomicUpdate(() {
        a.set(1);
        b.set(2);
      });

      expect(seen, ['a1', 'b2']);
    });
  });

  group('AtomSelector re-selects when the selector changes', () {
    testWidgets('new index shows the new item', (tester) async {
      final atom = Atom<List<String>>(['zero', 'one'], autoDispose: false);

      await tester.pumpWidget(_IndexedSelector(atom, 0));
      expect(find.text('zero'), findsOneWidget);

      await tester.pumpWidget(_IndexedSelector(atom, 1));
      expect(find.text('one'), findsOneWidget);
    });

    testWidgets('a throwing selector keeps the last good value',
        (tester) async {
      final atom = Atom<int>(1, autoDispose: false);

      await tester.pumpWidget(AtomSelector<int, String>(
        atom: atom,
        selector: (v) => v < 0 ? throw StateError('negative') : 'v$v',
        builder: (_, s) => Text(s, textDirection: TextDirection.ltr),
      ));

      atom.set(-1);
      await tester.pump();
      expect(find.text('v1'), findsOneWidget);
    });
  });

  group('Derived atoms release their dispose hook on the source', () {
    late Atom<int> source;
    late int baseline;

    setUp(() {
      source = Atom<int>(0, autoDispose: false);
      baseline = source.debugDisposeCallbackCount;
    });

    void expectReleased(void Function() createAndDispose) {
      createAndDispose();
      expect(source.debugDisposeCallbackCount, baseline);
    }

    test('map', () => expectReleased(() => source.map((v) => v).dispose()));
    test('where',
        () => expectReleased(() => source.where((v) => v > 0).dispose()));
    test(
        'debounce',
        () => expectReleased(
            () => source.debounce(const Duration(seconds: 1)).dispose()));
    test(
        'throttle',
        () => expectReleased(
            () => source.throttle(const Duration(seconds: 1)).dispose()));
    test('combine', () {
      final other = Atom<int>(0, autoDispose: false);
      final otherBaseline = other.debugDisposeCallbackCount;
      source.combine(other).dispose();
      expect(source.debugDisposeCallbackCount, baseline);
      expect(other.debugDisposeCallbackCount, otherBaseline);
    });

    test('asStream after cancel', () async {
      final sub = source.asStream().listen((_) {});
      await _flushMicrotasks();
      await sub.cancel();
      expect(source.debugDisposeCallbackCount, baseline);
      expect(source.hasListeners, isFalse);
    });

    test('asStream never listened, source disposed', () {
      source.asStream();
      expect(() => source.dispose(), returnsNormally);
    });

    test('async extensions', () {
      final asyncSource = AsyncAtom<int>(autoDispose: false);
      final asyncBaseline = asyncSource.debugDisposeCallbackCount;

      asyncSource.mapAsync((v) => v).dispose();
      asyncSource.debounceAsync(const Duration(seconds: 1)).dispose();
      asyncSource.chain<int>((v) async => v).dispose();
      asyncSource.cached().dispose();
      source.asyncMap<int>((v) async => v).dispose();

      expect(asyncSource.debugDisposeCallbackCount, asyncBaseline);
      expect(source.debugDisposeCallbackCount, baseline);
    });

    test('disposing the source still disposes the derived atom', () {
      final mapped = source.map((v) => v * 2);
      source.dispose();
      expect(mapped.isDisposed, isTrue);
    });
  });

  group('atomicUpdate rejects async callbacks', () {
    test('throws AssertionError and rolls back synchronous writes', () {
      final atom = Atom<int>(0, autoDispose: false);

      expect(
        () => atomicUpdate(() async {
          atom.set(1);
          await Future<void>.delayed(Duration.zero);
        }),
        throwsA(isA<AssertionError>()),
      );
      expect(atom.value, 0);
    });
  });
}
