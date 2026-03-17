import 'package:atomic_flutter/atomic_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Clean up global middleware after each test
  tearDown(Atom.clearMiddleware);

  group('Per-atom middleware', () {
    test('transforms value before storing', () {
      final atom = Atom<int>(
        0,
        autoDispose: false,
        middleware: [(old, next) => next.clamp(0, 10)],
      );

      atom.set(5);
      expect(atom.value, 5);

      atom.set(15); // clamped to 10
      expect(atom.value, 10);

      atom.set(-3); // clamped to 0
      expect(atom.value, 0);

      atom.dispose();
    });

    test('can block updates by returning oldValue', () {
      final atom = Atom<int>(
        5,
        autoDispose: false,
        middleware: [(old, next) => next.isEven ? next : old],
      );

      atom.set(4); // even — allowed
      expect(atom.value, 4);

      atom.set(7); // odd — blocked
      expect(atom.value, 4);

      atom.dispose();
    });

    test('chains multiple transformers in order', () {
      final atom = Atom<int>(
        0,
        autoDispose: false,
        middleware: [
          (old, next) => next * 2, // double first
          (old, next) => next + 1, // then add 1
        ],
      );

      atom.set(3); // 3*2=6, 6+1=7
      expect(atom.value, 7);

      atom.dispose();
    });

    test('does not fire listeners when update is blocked', () {
      int listenerCalls = 0;
      final atom = Atom<int>(
        5,
        autoDispose: false,
        middleware: [(old, next) => next > 100 ? old : next],
      );
      atom.addListener((_) => listenerCalls++);

      atom.set(10); // allowed
      expect(listenerCalls, 1);

      atom.set(200); // blocked — returns old value 10, no change
      expect(listenerCalls, 1);

      atom.dispose();
    });
  });

  group('Global middleware', () {
    test('applies to all atoms', () {
      final log = <String>[];
      Atom.addMiddleware(_RecordingMiddleware(log));

      final a = Atom<int>(0, autoDispose: false);
      final b = Atom<String>('hi', autoDispose: false);

      a.set(1);
      b.set('bye');

      expect(log, ['int:0→1', 'String:hi→bye']);

      a.dispose();
      b.dispose();
    });

    test('can transform values globally', () {
      Atom.addMiddleware(_DoubleIntMiddleware());

      final atom = Atom<int>(0, autoDispose: false);
      atom.set(5);
      expect(atom.value, 10); // doubled by global middleware

      atom.dispose();
    });

    test('removeMiddleware stops applying it', () {
      final log = <String>[];
      final mw = _RecordingMiddleware(log);
      Atom.addMiddleware(mw);

      final atom = Atom<int>(0, autoDispose: false);
      atom.set(1);
      expect(log.length, 1);

      Atom.removeMiddleware(mw);
      atom.set(2);
      expect(log.length, 1); // no new entries

      atom.dispose();
    });

    test('global runs after per-atom transformers', () {
      final order = <String>[];

      Atom.addMiddleware(_OrderMiddleware(order, 'global'));

      final atom = Atom<int>(
        0,
        autoDispose: false,
        middleware: [(old, next) {
          order.add('local');
          return next;
        }],
      );

      atom.set(1);
      expect(order, ['local', 'global']);

      atom.dispose();
    });

    test('does not apply to computed atoms', () {
      final log = <String>[];
      Atom.addMiddleware(_RecordingMiddleware(log));

      final source = Atom<int>(0, autoDispose: false);
      final derived = computed<int>(
        () => source.value * 2,
        tracked: [source],
        autoDispose: false,
      );

      source.set(5);

      // Only source change logged, not the computed atom's internal update
      expect(log.where((e) => e.startsWith('int:')), ['int:0→5']);
      expect(log.where((e) => e.contains('computed')), isEmpty);

      source.dispose();
      derived.dispose();
    });
  });

  group('LoggingMiddleware', () {
    test('is a no-op in release mode (passes value through)', () {
      // LoggingMiddleware only prints inside assert(), so in release builds
      // it's a pure passthrough. We test that it doesn't modify values.
      final mw = const LoggingMiddleware();
      final atom = Atom<int>(0, autoDispose: false);
      final result = mw.onSet(atom, 0, 42);
      expect(result, 42);
      atom.dispose();
    });
  });
}

// ---------------------------------------------------------------------------
// Test middleware helpers
// ---------------------------------------------------------------------------

class _RecordingMiddleware extends AtomMiddleware {
  final List<String> log;
  const _RecordingMiddleware(this.log);

  @override
  T onSet<T>(Atom<T> atom, T oldValue, T newValue) {
    log.add('${T.toString()}:$oldValue→$newValue');
    return newValue;
  }
}

class _DoubleIntMiddleware extends AtomMiddleware {
  @override
  T onSet<T>(Atom<T> atom, T oldValue, T newValue) {
    if (newValue is int) return (newValue * 2) as T;
    return newValue;
  }
}

class _OrderMiddleware extends AtomMiddleware {
  final List<String> order;
  final String label;
  const _OrderMiddleware(this.order, this.label);

  @override
  T onSet<T>(Atom<T> atom, T oldValue, T newValue) {
    order.add(label);
    return newValue;
  }
}
