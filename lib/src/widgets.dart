import 'package:flutter/widgets.dart';
import 'core.dart';

/// Flutter widget that efficiently subscribes to atoms
///
/// Rebuilds only when the atom's value changes.
class AtomBuilder<T> extends StatefulWidget {
  /// The atom to subscribe to
  final Atom<T> atom;

  /// Builder function that receives the current value
  final Widget Function(BuildContext context, T value) builder;

  /// Creates an AtomBuilder widget
  ///
  /// [atom]: The atom to subscribe to
  /// [builder]: Builder function that receives the current value
  const AtomBuilder({
    Key? key,
    required this.atom,
    required this.builder,
  }) : super(key: key);

  @override
  State<AtomBuilder<T>> createState() => _AtomBuilderState<T>();
}

class _AtomBuilderState<T> extends State<AtomBuilder<T>> {
  late T _value;

  @override
  void initState() {
    super.initState();
    _value = widget.atom.value;
    widget.atom.addListener(_onValueChanged);
  }

  @override
  void didUpdateWidget(AtomBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atom != widget.atom) {
      oldWidget.atom.removeListener(_onValueChanged);
      _value = widget.atom.value;
      widget.atom.addListener(_onValueChanged);
    }
  }

  @override
  void dispose() {
    widget.atom.removeListener(_onValueChanged);
    super.dispose();
  }

  void _onValueChanged(T newValue) {
    if (mounted) {
      setState(() {
        _value = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _value);
  }
}

/// Widget that subscribes to multiple atoms
///
/// Rebuilds when any of the atoms' values change.
class MultiAtomBuilder extends StatefulWidget {
  /// The atoms to subscribe to
  final List<Atom> atoms;

  /// Builder function for creating the widget
  final Widget Function(BuildContext context) builder;

  /// Creates a MultiAtomBuilder widget
  ///
  /// [atoms]: The list of atoms to subscribe to
  /// [builder]: Builder function for creating the widget
  const MultiAtomBuilder({
    Key? key,
    required this.atoms,
    required this.builder,
  }) : super(key: key);

  @override
  State<MultiAtomBuilder> createState() => _MultiAtomBuilderState();
}

class _MultiAtomBuilderState extends State<MultiAtomBuilder> {
  final Map<Atom, VoidCallback> _listeners = {};

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void didUpdateWidget(MultiAtomBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_listsEqual(oldWidget.atoms, widget.atoms)) {
      _removeListeners();
      _setupListeners();
    }
  }

  void _setupListeners() {
    for (final atom in widget.atoms) {
      final listener = () => _onAtomChanged();
      atom.addListener((value) => listener());
      _listeners[atom] = listener;
    }
  }

  void _removeListeners() {
    for (final entry in _listeners.entries) {
      final atom = entry.key;
      final listener = entry.value;
      atom.removeListener((value) => listener());
    }
    _listeners.clear();
  }

  void _onAtomChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _listsEqual(List a, List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _removeListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }
}

/// Widget that only rebuilds when selected part of atom changes
class AtomSelector<T, S> extends StatefulWidget {
  /// The atom to subscribe to
  final Atom<T> atom;

  /// Selector function that picks a part of the atom's value
  final S Function(T state) selector;

  /// Builder function that receives the selected value
  final Widget Function(BuildContext context, S selectedValue) builder;

  /// Creates an AtomSelector widget
  ///
  /// [atom]: The atom to subscribe to
  /// [selector]: Function that selects a part of the atom's value
  /// [builder]: Builder function that receives the selected value
  const AtomSelector({
    Key? key,
    required this.atom,
    required this.selector,
    required this.builder,
  }) : super(key: key);

  @override
  State<AtomSelector<T, S>> createState() => _AtomSelectorState<T, S>();
}

class _AtomSelectorState<T, S> extends State<AtomSelector<T, S>> {
  late S selectedValue;

  @override
  void initState() {
    super.initState();
    selectedValue = widget.selector(widget.atom.value);
    widget.atom.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.atom.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged(T value) {
    final newSelectedValue = widget.selector(value);
    if (newSelectedValue != selectedValue) {
      setState(() {
        selectedValue = newSelectedValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, selectedValue);
  }
}
