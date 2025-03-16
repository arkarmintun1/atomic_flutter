# atomic_flutter

<p align="center">
  <img src="https://raw.githubusercontent.com/arkarmintun1/atomic_flutter/main/assets/atomic_flutter_logo.svg" width="150" alt="AtomicFlutter Logo">
</p>

[![pub package](https://img.shields.io/pub/v/atomic_flutter.svg)](https://pub.dev/packages/atomic_flutter)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)

AtomicFlutter is a lightweight, reactive state management solution for Flutter applications. It provides a simple way to create, manage, and react to state changes with minimal boilerplate and maximum type safety.

## Table of Contents

- [atomic_flutter](#atomic_flutter)
  - [Table of Contents](#table-of-contents)
  - [Installation](#installation)
  - [Core Concepts](#core-concepts)
    - [Key Features](#key-features)
  - [Basic Usage](#basic-usage)
    - [Creating Atoms](#creating-atoms)
    - [Reading and Updating Atoms](#reading-and-updating-atoms)
  - [Widgets](#widgets)
    - [AtomBuilder](#atombuilder)
    - [MultiAtomBuilder](#multiatombuilder)
    - [AtomSelector](#atomselector)
  - [Derived State](#derived-state)
  - [Domain-Specific Atoms](#domain-specific-atoms)
  - [Extensions](#extensions)
    - [effect](#effect)
    - [asStream](#asstream)
    - [select](#select)
    - [debounce](#debounce)
    - [throttle](#throttle)
  - [Memory Management](#memory-management)
    - [Options](#options)
  - [Best Practices](#best-practices)
    - [Atom Organization](#atom-organization)
  - [Debugging](#debugging)
  - [Advanced Patterns](#advanced-patterns)
    - [Time-Travel Debugging](#time-travel-debugging)
    - [Persistent State](#persistent-state)
    - [Form Validation](#form-validation)
    - [Authentication Flow](#authentication-flow)
  - [Performance Considerations](#performance-considerations)
    - [Minimizing Rebuilds](#minimizing-rebuilds)
    - [Memory Usage](#memory-usage)
  - [Comparison with Other Solutions](#comparison-with-other-solutions)
    - [Advantages of AtomicFlutter](#advantages-of-atomicflutter)
    - [When to Consider Alternatives](#when-to-consider-alternatives)
  - [Real-World Examples](#real-world-examples)
    - [User Settings](#user-settings)
    - [Shopping Cart](#shopping-cart)
  - [Conclusion](#conclusion)
  - [License](#license)

## Installation

Add AtomicFlutter to your `pubspec.yaml`:

```yaml
dependencies:
  atomic_flutter: ^0.1.0
```

Then import it in your Dart files:

```dart
import 'package:atomic_flutter/atomic_flutter.dart';
```

## Core Concepts

AtomicFlutter is based on the concept of **atoms** - individual units of state that can be observed and updated. It uses a reactive programming model where UI components subscribe to atoms and automatically rebuild when the atom's value changes.

### Key Features

- 🔄 **Reactive State Management**: Automatically update UI when state changes
- 🧩 **Composable Atoms**: Build complex state from simple primitives
- 🧠 **Domain-Driven Design**: Create domain-specific atoms with integrated business logic
- 🚮 **Automatic Memory Management**: Dispose of unused state to prevent memory leaks
- 📦 **Minimal Dependencies**: No external libraries required
- 🔍 **Type Safety**: Full type safety with no string-based lookups
- 🔧 **Extensible**: Easy to extend with custom functionality
- 🧲 **Debugging Support**: Track atom changes and history

## Basic Usage

### Creating Atoms

An atom is a container for a piece of state:

```dart
// Create an atom with an initial value
final counterAtom = Atom<int>(0);

// Atom with an ID (useful for debugging)
final nameAtom = Atom<String>('', id: 'nameAtom');

// Atom with custom auto-disposal settings
final settingsAtom = Atom<Map<String, dynamic>>(
  {},
  autoDispose: true,
  disposeTimeout: Duration(minutes: 5),
);
```

### Reading and Updating Atoms

```dart
// Read the current value
int count = counterAtom.value;

// Update the value directly
counterAtom.set(5);

// Update based on the current value
counterAtom.update((current) => current + 1);

// Batch multiple updates to prevent intermediate rebuilds
counterAtom.batch(() {
  counterAtom.set(0);
  nameAtom.set('New User');
});
```

## Widgets

AtomicFlutter provides several widgets for efficiently connecting your UI to atoms:

### AtomBuilder

Rebuilds only when the atom's value changes:

```dart
AtomBuilder<int>(
  atom: counterAtom,
  builder: (context, count) {
    return Text('Count: $count');
  },
);
```

### MultiAtomBuilder

Rebuilds when any of the specified atoms change:

```dart
MultiAtomBuilder(
  atoms: [userAtom, themeAtom],
  builder: (context) {
    final user = userAtom.value;
    final theme = themeAtom.value;

    return Text('Hello ${user.name}', style: theme.textStyle);
  },
);
```

### AtomSelector

Rebuilds only when a selected part of an atom changes:

```dart
AtomSelector<UserProfile, String>(
  atom: userProfileAtom,
  selector: (profile) => profile.name,
  builder: (context, name) {
    return Text('Name: $name');
  },
);
```

## Derived State

You can create atoms that derive their value from other atoms using the `computed` function:

```dart
// Define primary atoms
final priceAtom = Atom<double>(10.0);
final quantityAtom = Atom<int>(2);

// Create a computed atom that depends on the other atoms
final totalAtom = computed<double>(
  () => priceAtom.value * quantityAtom.value,
  tracked: [priceAtom, quantityAtom],
  id: 'totalPrice',
);

// totalAtom.value will automatically update when either price or quantity changes
```

## Domain-Specific Atoms

For cleaner code, extend `Atom` to create domain-specific atoms:

```dart
class CartAtom extends Atom<Cart> {
  CartAtom() : super(const Cart(), id: 'cart', autoDispose: false);

  void addProduct(Product product, int quantity) {
    update((cart) => cart.addItem(
      CartItem(product: product, quantity: quantity)
    ));
  }

  void removeProduct(int productId) {
    update((cart) => cart.removeItem(productId));
  }

  bool hasProduct(int productId) {
    return value.items.any((item) => item.product.id == productId);
  }
}

// Usage
final cartAtom = CartAtom();
cartAtom.addProduct(product, 2);
```

## Extensions

AtomicFlutter provides several useful extensions on the Atom class:

### effect

Execute side effects when an atom changes:

```dart
// Run a function whenever the atom changes
final cleanup = userAtom.effect((user) {
  analytics.logUserChanged(user);
});

// Later, call the returned function to stop the effect
cleanup();
```

### asStream

Convert an atom to a Stream:

```dart
// Get a stream of the atom's values
Stream<User> userStream = userAtom.asStream();

// Use with StreamBuilder or other stream-based APIs
StreamBuilder<User>(
  stream: userStream,
  builder: (context, snapshot) {
    // ...
  },
);
```

### select

Shorthand for creating an AtomSelector:

```dart
userAtom.select(
  selector: (user) => user.name,
  builder: (context, name) {
    return Text(name);
  },
);
```

### debounce

Create a new atom that updates only after a delay:

```dart
// Create a search term atom
final searchTermAtom = Atom<String>('');

// Create a debounced version that only updates after 300ms of inactivity
final debouncedSearchAtom = searchTermAtom.debounce(Duration(milliseconds: 300));

// Use the debounced atom for API calls to avoid too many requests
searchTermAtom.effect((term) {
  // This will run on every keystroke
  print('Typing: $term');
});

debouncedSearchAtom.effect((term) {
  // This will only run after typing stops for 300ms
  api.search(term);
});
```

### throttle

Create a new atom that updates at most once per time period:

```dart
// Create a throttled atom that updates at most once per second
final throttledPositionAtom = positionAtom.throttle(Duration(seconds: 1));
```

## Memory Management

AtomicFlutter includes an automatic memory management system:

- Reference counting of atom usage
- Automatic disposal of unused atoms
- Configurable disposal timeouts
- Manual disposal when needed

```dart
// Global atom that never disposes
final themeAtom = Atom<ThemeMode>(ThemeMode.system, autoDispose: false);

// Screen-specific atom that auto-disposes after 2 minutes of disuse
final searchAtom = Atom<String>('', autoDispose: true);

// Custom disposal timeout
final cacheAtom = Atom<Map<String, dynamic>>(
  {},
  autoDispose: true,
  disposeTimeout: Duration(minutes: 30),
);

// Register disposal callback
cacheAtom.onDispose(() {
  // Cleanup code here
});

// Manually dispose
void cleanup() {
  cacheAtom.dispose();
}
```

### Options

- Use `autoDispose: true` for atoms that should be cleaned up when no longer used
- Set appropriate `disposeTimeout` values based on your app's needs
- Call `dispose()` explicitly for atoms that you want to immediately clean up

## Best Practices

### Atom Organization

Organize your atoms based on feature or domain:

```dart
// User feature atoms
final userAtom = Atom<User?>(null, id: 'user');
final isAuthenticatedAtom = computed<bool>(
  () => userAtom.value != null,
  tracked: [userAtom],
);

// Cart feature atoms
final cartItemsAtom = Atom<List<CartItem>>([], id: 'cartItems');
final cartTotalAtom = computed<double>(
  () => cartItemsAtom.value.fold(
    0,
    (total, item) => total + item.price * item.quantity,
  ),
  tracked: [cartItemsAtom],
);
```

## Debugging

AtomicFlutter includes built-in debugging tools:

```dart
// Enable debug logging
enableDebugMode();

// Set the default timeout for auto-disposal
setDefaultDisposeTimeout(Duration(minutes: 1));

// Print debug information about all atoms
AtomDebugger.printAtomInfo();
```

## Advanced Patterns

### Time-Travel Debugging

Implement undo/redo functionality by tracking atom history:

```dart
class TimeTravel<T> {
  final Atom<T> atom;
  final Atom<List<T>> historyAtom;
  final Atom<int> positionAtom;

  TimeTravel({required this.atom, required String id})
      : historyAtom = Atom<List<T>>([atom.value], id: '${id}_history'),
        positionAtom = Atom<int>(0, id: '${id}_position') {
    // Record history when atom changes
    atom.addListener(_recordHistory);
  }

  void _recordHistory(T value) {
    // Implementation details here
  }

  // Undo/redo methods
  void undo() { /* ... */ }
  void redo() { /* ... */ }
}
```

### Persistent State

Save atom values to persistent storage:

```dart
// Create a persistent atom
class PersistentAtom<T> {
  final Atom<T> atom;
  final String key;
  final Future<void> Function(String, T) saveFunction;
  final Future<T?> Function(String) loadFunction;

  PersistentAtom({
    required T initial,
    required this.key,
    required this.saveFunction,
    required this.loadFunction,
    String? id,
  }) : atom = Atom<T>(initial, id: id) {
    // Load initial value
    loadFunction(key).then((value) {
      if (value != null) {
        atom.set(value);
      }
    });

    // Save when value changes
    atom.addListener((value) {
      saveFunction(key, value);
    });
  }

  T get value => atom.value;
  void set(T value) => atom.set(value);
  void update(T Function(T current) updater) => atom.update(updater);
}
```

### Form Validation

Implement form validation using computed atoms:

```dart
// Form field atoms
final emailAtom = Atom<String>('');
final passwordAtom = Atom<String>('');

// Validation atoms
final emailErrorAtom = computed<String?>(
  () {
    final email = emailAtom.value;
    if (email.isEmpty) return 'Email is required';
    if (!email.contains('@')) return 'Invalid email format';
    return null;
  },
  tracked: [emailAtom],
);

final passwordErrorAtom = computed<String?>(
  () {
    final password = passwordAtom.value;
    if (password.isEmpty) return 'Password is required';
    if (password.length < 6) return 'Password must be at least 6 characters';
    return null;
  },
  tracked: [passwordAtom],
);

// Overall form validity
final formValidAtom = computed<bool>(
  () {
    return emailErrorAtom.value == null &&
           passwordErrorAtom.value == null &&
           emailAtom.value.isNotEmpty &&
           passwordAtom.value.isNotEmpty;
  },
  tracked: [emailErrorAtom, passwordErrorAtom, emailAtom, passwordAtom],
);
```

### Authentication Flow

Implement a typical authentication flow:

```dart
// Auth state enum
enum AuthState { initial, loading, authenticated, unauthenticated, error }

// Auth atoms
final authStateAtom = Atom<AuthState>(AuthState.initial);
final currentUserAtom = Atom<User?>(null);
final authErrorAtom = Atom<String?>(null);

// Auth controller
class AuthController {
  Future<void> login(String email, String password) async {
    try {
      // Set loading state
      authStateAtom.set(AuthState.loading);
      authErrorAtom.set(null);

      // Attempt login
      final user = await authService.login(email, password);

      // Update atoms with batch to avoid multiple rebuilds
      authStateAtom.batch(() {
        currentUserAtom.set(user);
        authStateAtom.set(AuthState.authenticated);
      });
    } catch (e) {
      // Update error state
      authStateAtom.batch(() {
        authErrorAtom.set(e.toString());
        authStateAtom.set(AuthState.error);
      });
    }
  }

  Future<void> logout() {
    // Implementation details here
  }
}
```

## Performance Considerations

### Minimizing Rebuilds

- Use `AtomSelector` when you only care about a specific part of an atom's state
- Use `batch` to group related state updates
- Use `throttle` or `debounce` for frequently changing state
- Keep atoms small and focused to minimize unnecessary rebuilds

### Memory Usage

- Enable auto-dispose for ephemeral atoms
- Set appropriate dispose timeouts for different kinds of atoms
- Clean up effects and listeners when no longer needed

## Comparison with Other Solutions

### Advantages of AtomicFlutter

- **Lightweight**: Minimal API surface and small footprint
- **Fine-grained reactivity**: Only rebuilds what's necessary
- **Type safety**: Full type safety across the entire state management solution
- **Predictable**: Direct state updates with clear data flow
- **Memory efficient**: Automatic disposal of unused state
- **Composable**: Easy to compose atoms and derived state

### When to Consider Alternatives

- For global immutable state with middleware, consider **Redux**
- For larger applications with extensive middleware needs, consider **Bloc**
- For simpler state management needs, consider **Provider** or **Riverpod**

## Real-World Examples

### User Settings

```dart
// Settings atoms
final darkModeAtom = Atom<bool>(false);
final fontSizeAtom = Atom<double>(16.0);
final notificationsEnabledAtom = Atom<bool>(true);

// Computed atoms
final themeAtom = computed<ThemeData>(
  () {
    final isDarkMode = darkModeAtom.value;
    final fontSize = fontSizeAtom.value;

    return isDarkMode
        ? ThemeData.dark().copyWith(
            textTheme: TextTheme(
              bodyLarge: TextStyle(fontSize: fontSize),
            ),
          )
        : ThemeData.light().copyWith(
            textTheme: TextTheme(
              bodyLarge: TextStyle(fontSize: fontSize),
            ),
          );
  },
  tracked: [darkModeAtom, fontSizeAtom],
);

// Settings persistence
void initSettings() {
  loadSettings().then((settings) {
    darkModeAtom.set(settings.darkMode);
    fontSizeAtom.set(settings.fontSize);
    notificationsEnabledAtom.set(settings.notificationsEnabled);
  });

  // Save settings when they change
  darkModeAtom.effect((value) => saveSettings('darkMode', value));
  fontSizeAtom.effect((value) => saveSettings('fontSize', value));
  notificationsEnabledAtom.effect((value) => saveSettings('notificationsEnabled', value));
}
```

### Shopping Cart

```dart
// Cart atoms
final cartItemsAtom = Atom<List<CartItem>>([]);

// Derived atoms
final cartTotalAtom = computed<double>(
  () => cartItemsAtom.value.fold(
    0,
    (total, item) => total + item.price * item.quantity,
  ),
  tracked: [cartItemsAtom],
);

final cartItemCountAtom = computed<int>(
  () => cartItemsAtom.value.fold(
    0,
    (total, item) => total + item.quantity,
  ),
  tracked: [cartItemsAtom],
);

// Cart controller
class CartController {
  void addToCart(Product product) {
    cartItemsAtom.update((items) {
      final existingIndex = items.indexWhere(
        (item) => item.product.id == product.id,
      );

      if (existingIndex >= 0) {
        // Update existing item quantity
        final updatedItems = List<CartItem>.from(items);
        final item = updatedItems[existingIndex];
        updatedItems[existingIndex] = item.copyWith(
          quantity: item.quantity + 1,
        );
        return updatedItems;
      } else {
        // Add new item
        return [...items, CartItem(product: product)];
      }
    });
  }

  void removeFromCart(String productId) {
    // Implementation details here
  }
}
```

See the [example folder](example/) for a full e-commerce app demo.

## Conclusion

AtomicFlutter provides a lightweight, type-safe, and efficient way to manage state in Flutter applications. By focusing on small, composable atoms of state, it enables a reactive programming model with minimal boilerplate.

Whether you're building a simple counter app or a complex e-commerce application, AtomicFlutter's flexible API and powerful features make it a great choice for state management.

For more detailed examples and advanced usage patterns, check out the example applications included in the package.

## License

[MIT License](LICENSE)
