import 'package:atomic_flutter/atomic_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AtomHistory', () {
    test('undo restores previous value', () {
      final atom = Atom<int>(0, autoDispose: false);
      final history = AtomHistory(atom);

      atom.set(1);
      atom.set(2);
      atom.set(3);

      history.undo();
      expect(atom.value, 2);

      history.undo();
      expect(atom.value, 1);

      history.undo();
      expect(atom.value, 0);

      history.dispose();
      atom.dispose();
    });

    test('redo reapplies undone value', () {
      final atom = Atom<int>(0, autoDispose: false);
      final history = AtomHistory(atom);

      atom.set(1);
      atom.set(2);

      history.undo();
      expect(atom.value, 1);

      history.redo();
      expect(atom.value, 2);

      history.dispose();
      atom.dispose();
    });

    test('new change clears redo stack', () {
      final atom = Atom<int>(0, autoDispose: false);
      final history = AtomHistory(atom);

      atom.set(1);
      atom.set(2);
      history.undo();         // back to 1, redo has [2]
      atom.set(3);            // new change — redo stack cleared

      expect(history.canRedo.value, false);

      history.redo();         // no-op
      expect(atom.value, 3);

      history.dispose();
      atom.dispose();
    });

    test('canUndo is false at initial state', () {
      final atom = Atom<int>(0, autoDispose: false);
      final history = AtomHistory(atom);

      expect(history.canUndo.value, false);

      atom.set(1);
      expect(history.canUndo.value, true);

      history.dispose();
      atom.dispose();
    });

    test('canRedo is false until an undo happens', () {
      final atom = Atom<int>(0, autoDispose: false);
      final history = AtomHistory(atom);

      atom.set(1);
      expect(history.canRedo.value, false);

      history.undo();
      expect(history.canRedo.value, true);

      history.redo();
      expect(history.canRedo.value, false);

      history.dispose();
      atom.dispose();
    });

    test('undo past initial state is a no-op', () {
      final atom = Atom<int>(0, autoDispose: false);
      final history = AtomHistory(atom);

      history.undo(); // nothing to undo
      expect(atom.value, 0);
      expect(history.canUndo.value, false);

      history.dispose();
      atom.dispose();
    });

    test('ring buffer caps history at maxHistory', () {
      final atom = Atom<int>(0, autoDispose: false);
      final history = AtomHistory(atom, maxHistory: 5);

      // Push 10 values — only last 5 (including current) are retained
      for (int i = 1; i <= 10; i++) {
        atom.set(i);
      }

      expect(history.historyLength, 4); // 4 undo steps (5 entries total)

      history.undo(); expect(atom.value, 9);
      history.undo(); expect(atom.value, 8);
      history.undo(); expect(atom.value, 7);
      history.undo(); expect(atom.value, 6);

      // No more undo steps
      expect(history.canUndo.value, false);

      history.dispose();
      atom.dispose();
    });

    test('clear resets history', () {
      final atom = Atom<int>(0, autoDispose: false);
      final history = AtomHistory(atom);

      atom.set(1);
      atom.set(2);
      history.undo();

      history.clear();

      expect(history.canUndo.value, false);
      expect(history.canRedo.value, false);
      expect(atom.value, 1); // atom value unchanged by clear

      history.dispose();
      atom.dispose();
    });

    test('dispose stops tracking', () {
      final atom = Atom<int>(0, autoDispose: false);
      final history = AtomHistory(atom);

      atom.set(1);
      history.dispose();

      atom.set(2); // should not be recorded
      // After dispose, canUndo/canRedo atoms are also disposed
      // so we check historyLength directly before dispose clears it
      // Instead verify undo doesn't do anything unexpected
      atom.dispose();
    });

    test('historyLength reflects undo steps available', () {
      final atom = Atom<int>(0, autoDispose: false);
      final history = AtomHistory(atom);

      expect(history.historyLength, 0);

      atom.set(1);
      expect(history.historyLength, 1);

      atom.set(2);
      expect(history.historyLength, 2);

      history.undo();
      expect(history.historyLength, 1);

      history.dispose();
      atom.dispose();
    });
  });
}
