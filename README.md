# AtomicFlutter

A lightweight, reactive state management solution for Flutter applications. AtomicFlutter focuses on simplicity, performance, and type safety with minimal boilerplate.

## Features

- 🔄 **Reactive State Management**: Automatically update UI when state changes
- 🧩 **Composable Atoms**: Build complex state from simple primitives
- 🧠 **Domain-Driven Design**: Create domain-specific atoms with integrated business logic
- 🚮 **Automatic Memory Management**: Dispose of unused state to prevent memory leaks
- 📦 **Minimal Dependencies**: No external libraries required
- 🔍 **Type Safety**: Full type safety with no string-based lookups
- 🔧 **Extensible**: Easy to extend with custom functionality

## Installation

Add AtomicFlutter to your `pubspec.yaml`:

```yaml
dependencies:
  atomic_flutter: ^0.1.0
```

Then run:

```
flutter pub get
```

## Basic Usage

### Creating Atoms

```dart
// Simple atom
final counterAtom = Atom<int>(0);

// Atom with custom ID and auto-dispose settings
final userAtom = Atom<User?>(
  null,
  id: 'user',
  autoDispose: false,
);

// Computed atom that depends on other atoms
final isLoggedInAtom = computed<bool>(
  () => userAtom.value != null,
  tracked: [userAtom],
);
```

### Updating Atoms

```dart
// Set a new value
counterAtom.set(5);

// Update based on current value
counterAtom.update((count) => count + 1);

// Batch multiple updates
userAtom.batch(() {
  userAtom.set(user);
  cartAtom.set(cart);
});
```

### Using Atoms in UI

```dart
// Rebuild widget when atom changes
AtomBuilder(
  atom: counterAtom,
  builder: (context, count) {
    return Text('Count: $count');
  },
);

// Multiple atoms
MultiAtomBuilder(
  atoms: [userAtom, cartAtom],
  builder: (context) {
    return Text('${userAtom.value?.name} has ${cartAtom.value.itemCount} items');
  },
);

// Select specific parts of state for efficient rebuilds
userAtom.select(
  selector: (user) => user?.name,
  builder: (context, name) {
    return Text('Name: ${name ?? "Guest"}');
  },
);
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

## Debugging

AtomicFlutter includes built-in debugging tools:

```dart
// Enable debug mode
enableDebugMode();

// Set default auto-dispose timeout
setDefaultDisposeTimeout(Duration(minutes: 5));

// For extended debugging
AtomDebugger.printAtomInfo();
```

## Complete Example

See the [example folder](example/) for a full e-commerce app demo.

## License

[MIT License](LICENSE)