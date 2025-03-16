import 'package:atomic_flutter/atomic_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Counter Atom Tests', () {
    late Atom<int> counterAtom;

    setUp(() {
      counterAtom = Atom<int>(0, id: 'counterTest');
    });

    test('should have initial value of 0', () {
      expect(counterAtom.value, equals(0));
    });

    test('should update value correctly', () {
      counterAtom.set(5);
      expect(counterAtom.value, equals(5));

      counterAtom.update((current) => current + 3);
      expect(counterAtom.value, equals(8));
    });

    test('should notify listeners of changes', () {
      int notifiedValue = -1;
      counterAtom.addListener((value) => notifiedValue = value);

      counterAtom.set(10);
      expect(notifiedValue, equals(10));
    });
  });
}
