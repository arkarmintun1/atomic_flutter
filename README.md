# atomic_flutter

<p align="center">
  <img src="https://raw.githubusercontent.com/arkarmintun1/atomic_flutter/main/assets/atomic_flutter_logo.svg" width="150" alt="AtomicFlutter Logo">
</p>

[![pub package](https://img.shields.io/pub/v/atomic_flutter.svg)](https://pub.dev/packages/atomic_flutter)
[![Tests](https://github.com/arkarmintun1/atomic_flutter/actions/workflows/tests.yml/badge.svg)](https://github.com/arkarmintun1/atomic_flutter/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

AtomicFlutter is a lightweight, reactive state management solution for Flutter applications. It provides a simple way to create, manage, and react to state changes with minimal boilerplate and maximum type safety.

## Table of Contents

- [Installation](#installation)
- [Core Concepts](#core-concepts)
- [Basic Usage](#basic-usage)
  - [Creating Atoms](#creating-atoms)
  - [Reading and Updating Atoms](#reading-and-updating-atoms)
- [Widgets](#widgets)
  - [AtomBuilder](#atombuilder)
  - [MultiAtomBuilder](#multiatombuilder)
  - [AtomSelector](#atomselector)
  - [WatchAtom Mixin](#watchatom-mixin)
- [Derived State](#derived-state)
- [Async State Management](#async-state-management)
  - [AsyncAtom](#asyncatom)
  - [AsyncValue](#asyncvalue)
  - [AsyncAtom Operations](#asyncatom-operations)
  - [AsyncAtomBuilder](#asyncatombuilder)
- [Extensions](#extensions)
  - [effect](#effect)
  - [asStream](#asstream)
  - [select](#select)
  - [debounce](#debounce)
  - [throttle](#throttle)
  - [map](#map)
  - [where](#where)
  - [combine](#combine)
- [Async Extensions](#async-extensions)
  - [AsyncAtom Extensions](#asyncatom-extensions)
  - [Atom to AsyncAtom Extensions](#atom-to-asyncatom-extensions)
  - [Async Computed Functions](#async-computed-functions)
- [Batching Updates](#batching-updates)
  - [atomicUpdate](#atomicupdate)
  - [Per-atom batch](#per-atom-batch)
- [Middleware](#middleware)
  - [Global Middleware](#global-middleware)
  - [Per-atom Transformers](#per-atom-transformers)
  - [Built-in LoggingMiddleware](#built-in-loggingmiddleware)
- [Undo / Redo](#undo--redo)
- [Persistence](#persistence)
- [Domain-Specific Atoms](#domain-specific-atoms)
- [Memory Management](#memory-management)
- [Debugging](#debugging)
- [Best Practices](#best-practices)
- [Performance Considerations](#performance-considerations)
- [Comparison with Other Solutions](#comparison-with-other-solutions)
- [License](#license)

## Installation

```yaml
dependencies:
  atomic_flutter: ^0.5.0
```

```dart
import 'package:atomic_flutter/atomic_flutter.dart';
```

## Core Concepts

AtomicFlutter is based on the concept of **atoms** — individual units of state that can be observed and updated. UI components subscribe to atoms and automatically rebuild when the atom's value changes.

**Key features:**

- Reactive state management with automatic UI updates
- Async state with built-in loading / success / error states
- Composable derived state via `computed`
- Cross-atom batching with `atomicUpdate`
- Middleware for value transformation and logging
- Undo / redo history with a bounded ring buffer
- Persistence abstraction for any key-value store
- Automatic memory management via reference counting
- No external dependencies

## Basic Usage

### Creating Atoms

```dart
// Simple atom
final counterAtom = Atom<int>(0);

// With ID (useful for debugging and DevTools)
final nameAtom = Atom<String>('', id: 'nameAtom');

// With auto-disposal
final searchAtom = Atom<String>(
  '',
  autoDispose: true,
  disposeTimeout: Duration(minutes: 5),
);

// With custom equality (prevents unnecessary notifications)
final listAtom = Atom<List<int>>(
  [],
  equals: (a, b) => const ListEquality().equals(a, b),
);
```

### Reading and Updating Atoms

```dart
// Read
int count = counterAtom.value;

// Set directly
counterAtom.set(5);

// Update based on current value
counterAtom.update((current) => current + 1);
```

## Widgets

### AtomBuilder

Rebuilds only when the atom's value changes. Accepts an optional `child` that is not rebuilt when the atom changes:

```dart
AtomBuilder<int>(
  atom: counterAtom,
  builder: (context, count, child) {
    return Column(
      children: [
        Text('Count: $count'),
        child!, // not rebuilt on atom change
      ],
    );
  },
  child: const ExpensiveStaticWidget(),
);
```

### MultiAtomBuilder

Rebuilds when any of the listed atoms change:

```dart
MultiAtomBuilder(
  atoms: [userAtom, themeAtom],
  builder: (context) {
    return Text(
      'Hello ${userAtom.value.name}',
      style: themeAtom.value.textStyle,
    );
  },
);
```

### AtomSelector

Rebuilds only when a selected slice of an atom changes. Supports a custom `equals` function:

```dart
AtomSelector<UserProfile, String>(
  atom: userProfileAtom,
  selector: (profile) => profile.name,
  builder: (context, name) => Text('Name: $name'),
);

// With custom equality
AtomSelector<UserProfile, List<String>>(
  atom: userProfileAtom,
  selector: (profile) => profile.roles,
  equals: (a, b) => const ListEquality().equals(a, b),
  builder: (context, roles) => Text(roles.join(', ')),
);
```

### WatchAtom Mixin

Subscribe to atoms directly inside `build()` with no `AtomBuilder` wrapper. Subscriptions are reconciled automatically after each frame — atoms no longer referenced are unsubscribed.

```dart
class CounterPage extends StatefulWidget {
  const CounterPage({super.key});
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> with WatchAtom {
  @override
  Widget build(BuildContext context) {
    final count = watch(counterAtom);
    final name  = watch(nameAtom);

    return Column(
      children: [
        Text('$name: $count'),
        ElevatedButton(
          onPressed: () => counterAtom.update((v) => v + 1),
          child: const Text('Increment'),
        ),
      ],
    );
  }
}
```

`watch()` must be called inside `build()` — an assertion fires in debug mode if called elsewhere.

## Derived State

```dart
final priceAtom    = Atom<double>(10.0);
final quantityAtom = Atom<int>(2);

final totalAtom = computed<double>(
  () => priceAtom.value * quantityAtom.value,
  tracked: [priceAtom, quantityAtom],
);

// totalAtom updates automatically when price or quantity changes
```

## Async State Management

### AsyncAtom

```dart
final userAtom = AsyncAtom<User>();

// Execute an async operation
await userAtom.execute(() => api.fetchUser());

// Keep previous data visible while refreshing
await userAtom.execute(
  () => api.refreshUser(),
  keepPreviousData: true,
);
```

### AsyncValue

```dart
final v = userAtom.value;

if (v.isLoading) { /* show spinner   */ }
if (v.hasError)  { /* v.error, v.stackTrace */ }
if (v.hasValue)  { /* v.value        */ }

// Pattern matching
final widget = v.when(
  idle:    ()          => const Text('Tap to load'),
  loading: ()          => const CircularProgressIndicator(),
  success: (user)      => Text('Hello ${user.name}'),
  error:   (e, st)     => Text('Error: $e'),
);

// Optional pattern matching
final widget = v.maybeWhen(
  success: (user) => Text(user.name),
  orElse:  ()     => const SizedBox(),
);
```

### AsyncAtom Operations

```dart
await userAtom.executeAndStore(() => api.fetchUser()); // stores op for refresh
await userAtom.refresh();    // re-run the stored operation
userAtom.cancel();           // cancel in-flight operation
userAtom.clear();            // reset to idle
userAtom.setData(user);      // optimistic update
userAtom.setError(e, st);    // set error state directly
```

### AsyncAtomBuilder

Only `atom` and `builder` are required. All other states have sensible defaults. Providing `operation` enables both pull-to-refresh and a retry button on the error state — no flags needed.

```dart
// Minimal
AsyncAtomBuilder<User>(
  atom: userAtom,
  builder: (context, user) => Text(user.name),
);

// With defaults overridden
AsyncAtomBuilder<User>(
  atom: userAtom,
  builder:   (context, user)          => Text(user.name),
  idle:      (context)                => const Text('Tap to load'),
  loading:   (context, prev)          => prev != null
                                           ? Opacity(opacity: 0.5, child: Text(prev.name))
                                           : const CircularProgressIndicator(),
  error:     (context, e, st, prev)   => Text('Error: $e'),
  operation: () => api.fetchUser(),   // enables Retry button + pull-to-refresh
);
```

When `operation` is provided and `error` is not, a default error widget with a **Retry** button is shown automatically. The same `operation` is also used as the pull-to-refresh handler.

## Extensions

### effect

```dart
final stop = userAtom.effect((user) {
  analytics.logUserChanged(user);
});

stop(); // unsubscribe
```

### asStream

```dart
Stream<User> stream = userAtom.asStream();
```

### select

Creates a derived atom that only updates when the selected value changes:

```dart
final nameAtom = userAtom.select((u) => u.name);

// With custom equality
final tagsAtom = postAtom.select(
  (p) => p.tags,
  equals: (a, b) => const SetEquality().equals(a.toSet(), b.toSet()),
);
```

### debounce

```dart
final debouncedSearch = searchTermAtom.debounce(Duration(milliseconds: 300));
```

### throttle

```dart
final throttledPos = positionAtom.throttle(Duration(milliseconds: 100));
```

### map

```dart
final upperName = nameAtom.map((name) => name.toUpperCase());
```

### where

```dart
// Only propagates values that satisfy the predicate
final nonEmpty = nameAtom.where((name) => name.isNotEmpty);
```

### combine

```dart
// Combines two atoms into a record
final Atom<(User, Theme)> combined = userAtom.combine(themeAtom);
```

## Async Extensions

### AsyncAtom Extensions

```dart
// Debounce: wait for inactivity before executing
final debouncedSearch = searchAtom.debounceAsync(Duration(milliseconds: 300));

// Map success values to another type
final namesAtom = usersAtom.mapAsync((users) => users.map((u) => u.name).toList());

// Guard against concurrent calls
await dataAtom.executeIfNotLoading(() => api.fetch());

// Retry with exponential backoff
await dataAtom.executeWithRetry(
  () => api.fetch(),
  maxRetries: 3,
  delay: Duration(seconds: 1),
);

// Chain dependent operations
final processedAtom = rawAtom.chain((data) async => processData(data));

// Cache with TTL
final cachedAtom = dataAtom.cached(ttl: Duration(minutes: 5));
```

### Atom to AsyncAtom Extensions

```dart
// Wrap a regular atom as async
final asyncUser = userAtom.toAsync();

// Trigger an async fetch whenever a regular atom changes
final postsAtom = userIdAtom.asyncMap((userId) async {
  return api.fetchPosts(userId);
});
```

### Async Computed Functions

```dart
// Computed async atom
final profileAtom = computedAsync<UserProfile>(
  () async {
    final user     = userAtom.value;
    final settings = settingsAtom.value;
    return api.buildProfile(user, settings);
  },
  tracked: [userAtom, settingsAtom],
  debounce: Duration(milliseconds: 300),
);

// Combine multiple async atoms into one
final combinedAtom = combineAsync([userAtom, settingsAtom, prefsAtom]);
combinedAtom.value.when(
  success: (list) { /* list[0]=user, list[1]=settings, list[2]=prefs */ },
  loading: () => showLoading(),
  error:   (e, _) => showError(e),
  idle:    () => showIdle(),
);
```

## Batching Updates

### atomicUpdate

Defers all listener notifications until every atom in the block has been updated. Listeners fire exactly once per atom at the end of the outermost call — nested `atomicUpdate` calls are fully supported.

```dart
atomicUpdate(() {
  userAtom.set(newUser);
  cartAtom.set(newCart);
  themeAtom.set(newTheme);
});
// All three listeners fire here — once each

// Nesting works correctly
atomicUpdate(() {
  atomicUpdate(() { counterAtom.set(1); });
  counterAtom.set(2);
}); // listener fires once with value 2
```

If the block throws, dirty atoms are discarded and no listeners fire.

### Per-atom batch

Defers notifications on a single atom across multiple `.set()` calls:

```dart
counterAtom.batch(() {
  counterAtom.set(0);
  counterAtom.set(1);
  counterAtom.set(2);
}); // listener fires once with value 2
```

## Middleware

Middleware intercepts every `set()` call and can transform or log values before they are stored.

### Global Middleware

Applied to every atom:

```dart
class ClampMiddleware extends AtomMiddleware {
  const ClampMiddleware(this.min, this.max);
  final int min, max;

  @override
  T onSet<T>(Atom<T> atom, T oldValue, T newValue) {
    if (newValue is int) return newValue.clamp(min, max) as T;
    return newValue;
  }
}

Atom.addMiddleware(const ClampMiddleware(0, 100));
Atom.removeMiddleware(myMiddleware);
Atom.clearMiddleware();
```

### Per-atom Transformers

Applied only to a specific atom, runs before global middleware:

```dart
final volume = Atom<int>(
  50,
  middleware: [(old, next) => next.clamp(0, 100)],
);
```

### Built-in LoggingMiddleware

Logs every state change in debug mode — zero cost in release builds:

```dart
Atom.addMiddleware(const LoggingMiddleware());
// [AtomicFlutter] counter: 0 → 1
```

## Undo / Redo

`AtomHistory` wraps any `Atom<T>` with a bounded undo/redo stack backed by a ring buffer. `canUndo` and `canRedo` are exposed as `Atom<bool>` for reactive UI.

```dart
final counter = Atom<int>(0, autoDispose: false);
final history = AtomHistory(counter, maxHistory: 50);

counter.set(1);
counter.set(2);
counter.set(3);

history.undo(); // → 2
history.undo(); // → 1
history.redo(); // → 2

// Reactive undo button
AtomBuilder(
  atom: history.canUndo,
  builder: (ctx, canUndo, _) => ElevatedButton(
    onPressed: canUndo ? history.undo : null,
    child: const Text('Undo'),
  ),
);

print(history.historyLength); // undo steps available
history.clear();              // wipe history, keep current value
history.dispose();            // stop tracking
```

New changes after an undo clear the redo stack.

## Persistence

Implement `AtomStorage` to plug in any key-value store:

```dart
class SharedPreferencesStorage implements AtomStorage {
  SharedPreferencesStorage(this._prefs);
  final SharedPreferences _prefs;

  @override Future<String?> read(String key) async => _prefs.getString(key);
  @override Future<void> write(String key, String value) async =>
      _prefs.setString(key, value);
  @override Future<void> delete(String key) async => _prefs.remove(key);
}
```

`InMemoryAtomStorage` is provided out of the box for tests.

Use `persistAtom` to create an atom that automatically saves and restores its value:

```dart
final prefs = await SharedPreferences.getInstance();
final storage = SharedPreferencesStorage(prefs);

// Primitive
final counterAtom = persistAtom<int>(
  0,
  key: 'counter',
  storage: storage,
  fromJson: (v) => (v as num).toInt(),
  toJson:   (v) => v,
);

// Custom class
final settingsAtom = persistAtom<Settings>(
  Settings.defaults(),
  key: 'settings',
  storage: storage,
  fromJson: (v) => Settings.fromJson(v as Map<String, dynamic>),
  toJson:   (v) => v.toJson(),
);
```

The atom starts with `defaultValue` immediately and updates asynchronously once the stored value is read. Every subsequent `set()` is written back to storage automatically.

## Domain-Specific Atoms

Extend `Atom` to encapsulate business logic:

```dart
class CartAtom extends Atom<Cart> {
  CartAtom() : super(const Cart(), id: 'cart', autoDispose: false);

  void addProduct(Product product, {int quantity = 1}) {
    update((cart) => cart.addItem(CartItem(product: product, quantity: quantity)));
  }

  void removeProduct(int productId) {
    update((cart) => cart.removeItem(productId));
  }

  bool contains(int productId) =>
      value.items.any((item) => item.product.id == productId);
}

final cartAtom = CartAtom();
cartAtom.addProduct(product);
```

## Memory Management

```dart
// Never auto-disposes — good for global atoms
final themeAtom = Atom<ThemeMode>(ThemeMode.system, autoDispose: false);

// Auto-disposes when ref count reaches zero
final searchAtom = Atom<String>('', autoDispose: true);

// Custom timeout before disposal
final cacheAtom = Atom<Map<String, dynamic>>(
  {},
  autoDispose: true,
  disposeTimeout: Duration(minutes: 30),
);

// Cleanup hook
cacheAtom.onDispose(() { /* release resources */ });

// Manual disposal
cacheAtom.dispose();
```

## Debugging

```dart
// Enable debug logging and DevTools integration
enableDebugMode();

// Set global default for auto-dispose timeout
setDefaultDisposeTimeout(Duration(minutes: 1));

// Print info for all live atoms
AtomDebugger.printAtomInfo();

// Log all state changes (no-op in release builds)
Atom.addMiddleware(const LoggingMiddleware());
```

The built-in DevTools extension provides:

- **Atom Inspector** — live table of all atoms with search and detail view
- **Dependency Graph** — interactive force-directed graph of atom relationships
- **Async Timeline** — timeline of `AsyncAtom` state transitions
- **Performance Dashboard** — update frequency, rebuild rankings, hot atom detection

## Best Practices

**Organise by feature:**

```dart
// auth/atoms.dart
final userAtom            = Atom<User?>(null, id: 'user');
final isAuthenticatedAtom = computed<bool>(
  () => userAtom.value != null,
  tracked: [userAtom],
);

// cart/atoms.dart
final cartItemsAtom = Atom<List<CartItem>>([], id: 'cartItems');
final cartTotalAtom = computed<double>(
  () => cartItemsAtom.value.fold(0, (t, i) => t + i.price * i.quantity),
  tracked: [cartItemsAtom],
);
```

- Prefer `atomicUpdate` over sequential `set()` calls when multiple atoms share listeners or computed dependencies
- Use `AtomSelector` or `.select()` when only a slice of a large atom is needed
- Use `autoDispose: true` for screen-scoped atoms; `autoDispose: false` for global singletons
- Use `WatchAtom` mixin when you need multiple atoms in one widget without nesting multiple `AtomBuilder`s

## Performance Considerations

- `AtomSelector` / `.select()` rebuild only when the selected value changes
- `atomicUpdate` batches multiple atom changes into a single notification round
- `debounce` / `throttle` reduce notification frequency for high-frequency atoms
- Auto-dispose frees memory for atoms no longer in use
- `AtomBuilder`'s `child` parameter prevents rebuilding static sub-trees

## Comparison with Other Solutions

| | AtomicFlutter | Provider | Riverpod | Bloc |
|---|---|---|---|---|
| Boilerplate | Minimal | Low | Low | High |
| Async support | Built-in | Manual | Built-in | Built-in |
| Fine-grained reactivity | Yes | No | Yes | No |
| Undo / Redo | Built-in | Manual | Manual | Manual |
| Persistence | Built-in | Manual | Manual | Manual |
| Middleware | Built-in | No | No | Yes |
| External dependencies | None | flutter | flutter | flutter |

## License

[MIT License](LICENSE)
