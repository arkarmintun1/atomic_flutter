import 'dart:ui';

import 'package:atomic_flutter/atomic_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('persistAtom', () {
    test('starts with defaultValue before storage loads', () {
      final storage = InMemoryAtomStorage();
      final atom = persistAtom<int>(
        0,
        key: 'count',
        storage: storage,
        fromJson: (v) => (v as num).toInt(),
        toJson: (v) => v,
        autoDispose: false,
      );

      expect(atom.value, 0);
      atom.dispose();
    });

    test('loads persisted value from storage after construction', () async {
      final storage = InMemoryAtomStorage();
      await storage.write('count', '42');

      final atom = persistAtom<int>(
        0,
        key: 'count',
        storage: storage,
        fromJson: (v) => (v as num).toInt(),
        toJson: (v) => v,
        autoDispose: false,
      );

      // Initial value is default
      expect(atom.value, 0);

      // Wait for async load
      await Future.microtask(() {});
      expect(atom.value, 42);

      atom.dispose();
    });

    test('writes to storage when atom changes', () async {
      final storage = InMemoryAtomStorage();
      final atom = persistAtom<int>(
        0,
        key: 'count',
        storage: storage,
        fromJson: (v) => (v as num).toInt(),
        toJson: (v) => v,
        autoDispose: false,
      );

      atom.set(7);
      await Future.microtask(() {});

      final stored = await storage.read('count');
      expect(stored, '7');

      atom.dispose();
    });

    test('restores complex type via fromJson/toJson', () async {
      final storage = InMemoryAtomStorage();
      await storage.write('user', '{"name":"Alice","age":30}');

      final atom = persistAtom<Map<String, dynamic>>(
        {},
        key: 'user',
        storage: storage,
        fromJson: (v) => Map<String, dynamic>.from(v as Map),
        toJson: (v) => v,
        autoDispose: false,
      );

      await Future.microtask(() {});
      expect(atom.value['name'], 'Alice');
      expect(atom.value['age'], 30);

      atom.dispose();
    });

    test('persists updated complex value', () async {
      final storage = InMemoryAtomStorage();
      final atom = persistAtom<Map<String, dynamic>>(
        {},
        key: 'user',
        storage: storage,
        fromJson: (v) => Map<String, dynamic>.from(v as Map),
        toJson: (v) => v,
        autoDispose: false,
      );

      atom.set({'name': 'Bob', 'age': 25});
      await Future.microtask(() {});

      final stored = await storage.read('user');
      expect(stored, '{"name":"Bob","age":25}');

      atom.dispose();
    });

    test('missing key leaves atom at defaultValue', () async {
      final storage = InMemoryAtomStorage();
      final atom = persistAtom<int>(
        99,
        key: 'missing',
        storage: storage,
        fromJson: (v) => (v as num).toInt(),
        toJson: (v) => v,
        autoDispose: false,
      );

      await Future.microtask(() {});
      expect(atom.value, 99);

      atom.dispose();
    });

    test('two atoms with different keys are independent', () async {
      final storage = InMemoryAtomStorage();
      final a = persistAtom<int>(
        0,
        key: 'a',
        storage: storage,
        fromJson: (v) => (v as num).toInt(),
        toJson: (v) => v,
        autoDispose: false,
      );
      final b = persistAtom<int>(
        0,
        key: 'b',
        storage: storage,
        fromJson: (v) => (v as num).toInt(),
        toJson: (v) => v,
        autoDispose: false,
      );

      a.set(1);
      b.set(2);
      await Future.microtask(() {});

      expect((await storage.read('a')), '1');
      expect((await storage.read('b')), '2');

      a.dispose();
      b.dispose();
    });

    test('InMemoryAtomStorage clear removes all entries', () async {
      final storage = InMemoryAtomStorage();
      await storage.write('x', '1');
      await storage.write('y', '2');

      storage.clear();

      expect(await storage.read('x'), isNull);
      expect(await storage.read('y'), isNull);
    });

    test('user set() before storage load wins over persisted value', () async {
      final storage = InMemoryAtomStorage();
      await storage.write('race', '"old_value"');

      final atom = persistAtom<String>(
        'default',
        key: 'race',
        storage: storage,
        fromJson: (v) => v as String,
        toJson: (v) => v,
      );

      // User sets value before async storage read completes
      atom.set('user_value');

      // Let the storage read complete
      await Future.delayed(Duration.zero);

      // User value should take priority
      expect(atom.value, 'user_value');

      atom.dispose();
    });

    test('should not write back value restored from storage', () async {
      final storage = InMemoryAtomStorage();
      await storage.write('counter', '42');

      int writeCount = 0;
      final trackingStorage = _WriteCountingStorage(storage, () => writeCount++);

      final atom = persistAtom<int>(
        0,
        key: 'counter',
        storage: trackingStorage,
        fromJson: (v) => (v as num).toInt(),
        toJson: (v) => v,
      );

      // Wait for storage read to complete
      await Future.delayed(Duration.zero);

      expect(atom.value, 42);
      // Should not have written back the restored value
      expect(writeCount, 0);

      atom.dispose();
    });
  });
}

/// A wrapper around AtomStorage that counts write calls.
class _WriteCountingStorage implements AtomStorage {
  final AtomStorage _delegate;
  final VoidCallback _onWrite;

  _WriteCountingStorage(this._delegate, this._onWrite);

  @override
  Future<String?> read(String key) => _delegate.read(key);

  @override
  Future<void> write(String key, String value) {
    _onWrite();
    return _delegate.write(key, value);
  }

  @override
  Future<void> delete(String key) => _delegate.delete(key);
}
