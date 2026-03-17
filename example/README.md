# AtomicFlutter Example

This folder contains a comprehensive example demonstrating **all features** of AtomicFlutter v0.3.0.

## 📱 The Example App

### `main.dart` - Complete Feature Showcase
**An e-commerce app that demonstrates EVERY AtomicFlutter capability**

A comprehensive showcase featuring:

#### 🎯 Core Features
- ✅ Basic `Atom<T>` with state management
- ✅ `computed()` for derived state
- ✅ `AtomBuilder` for reactive UI
- ✅ `MultiAtomBuilder` for multiple atoms
- ✅ `AtomSelector` for performance optimization

#### ⚡ Async Features (NEW in v0.2.0+)
- ✅ `AsyncAtom<T>` with idle/loading/success/error states
- ✅ `AsyncBuilder` widget with retry and refresh
- ✅ `AsyncAtomBuilder` for custom async UI
- ✅ Pull-to-refresh support
- ✅ Automatic error isolation

#### 🛠️ Extension Methods
- ✅ `debounce()` - Debounced search (500ms delay)
- ✅ `throttle()` - Throttled updates (max 1/second)
- ✅ `map()` - Transform values (e.g., double counter)
- ✅ `where()` - Filter values (e.g., even numbers only)
- ✅ `combine()` - Combine multiple atoms
- ✅ `effect()` - Side effects on changes
- ✅ `asStream()` - Convert to Dart Stream

#### 🚀 Async Extensions (NEW in v0.2.0+)
- ✅ `debounceAsync()` - Debounced async operations
- ✅ `executeWithRetry()` - Exponential backoff retry
- ✅ `chain()` - Chain async operations
- ✅ `cached()` - TTL-based caching
- ✅ `mapAsync()` - Transform async values
- ✅ `combineAsync()` - Combine multiple async atoms
- ✅ `computedAsync()` - Async computed atoms

#### 🎨 Advanced Patterns
- ✅ Domain-specific atoms extending `Atom`/`AsyncAtom`
- ✅ Optimistic updates with backend sync
- ✅ Error handling and retry logic
- ✅ Memory management and auto-disposal
- ✅ Proper listener cleanup (v0.3.0 fixes)

**Run it:**
```bash
cd example
flutter run
```

---

## 🎓 Learning Path

### For Beginners
1. Start with the **Products tab** to see `AsyncAtom` in action
2. Look at basic `Atom` usage throughout the app
3. Explore `computed` atoms in the cart count/total

### For Intermediate Users
1. Study extension methods in the **Features Showcase tab**
2. Learn `AtomSelector` optimization in the Cart tab
3. Understand debounced search implementation

### For Advanced Users
1. Examine domain-specific atoms (`ProductsAsyncAtom`, `CartAtom`)
2. Study the debounced search implementation
3. Look at error handling and retry strategies
4. Review memory management patterns

---

## 📚 Code Highlights

### 1. AsyncAtom with AsyncBuilder
```dart
// In main.dart - Products tab
AsyncBuilder<List<Product>>(
  atom: productsAsyncAtom,
  enableRefresh: true,  // Pull-to-refresh
  enableRetry: true,    // Retry button on error
  onRefresh: () => productsAsyncAtom.loadProducts(),
  loading: (context) => CircularProgressIndicator(),
  error: (context, error) => ErrorWidget(error),
  builder: (context, products) => ProductList(products),
)
```

### 2. Debounced Search
```dart
// Search updates only after 500ms of inactivity
final searchQueryAtom = Atom<String>('');
final debouncedSearchAtom = searchQueryAtom.debounce(
  const Duration(milliseconds: 500),
);

// Use in computed atom
final filteredProductsAtom = computed<List<Product>>(
  () => products.where((p) =>
    p.name.contains(debouncedSearchAtom.value)
  ).toList(),
  tracked: [productsAsyncAtom, debouncedSearchAtom],
);
```

### 3. AtomSelector for Performance
```dart
// Only rebuilds when totalPrice changes, not entire cart
cartAtom.select<double>(
  selector: (cart) => cart.totalPrice,
  builder: (context, total) => Text('\$$total'),
)
```

### 4. Retry with Backoff
```dart
// Exponential backoff (default): 1s, 2s, 4s...
await productsAsyncAtom.executeWithRetry(
  () => api.getProducts(),
  maxRetries: 3,
  delay: const Duration(seconds: 1),
);

// Linear backoff: 1s, 2s, 3s...
await productsAsyncAtom.executeWithRetry(
  () => api.getProducts(),
  maxRetries: 3,
  delay: const Duration(seconds: 1),
  exponential: false,
);
```

### 5. Effect for Side Effects
```dart
// Execute code whenever cart changes
final cleanup = cartAtom.effect(
  (cart) => debugPrint('Cart: ${cart.itemCount} items'),
  runImmediately: true,
);

// Clean up when done
cleanup();
```

---

## 🐛 Testing Error Handling (v0.3.0)

The example includes error testing:

1. **Trigger Error**: Click the floating button in Products tab
2. **Retry**: Use the retry button to recover
3. **Exponential Backoff**: Test automatic retry with delays

This demonstrates the **robust error handling** added in v0.3.0 where:
- ✅ Errors in one listener don't crash others
- ✅ Async errors are properly isolated
- ✅ Memory leaks are prevented

---

## 💡 Tips for Exploration

### Experiment with Features
- Change debounce/throttle durations
- Add/remove products rapidly to see batching
- Toggle theme to see reactive updates
- Test error scenarios and recovery

### Debug Mode
Both examples enable debug mode:
```dart
enableDebugMode(); // See atom changes in console
```

### Performance Testing
- Use `AtomSelector` vs `AtomBuilder` to see rebuild differences
- Monitor memory with Flutter DevTools
- Test auto-disposal with timeout adjustments

---

## 📖 Additional Resources

- **Main README**: `../README.md`
- **CLAUDE.md**: Architecture and patterns
- **API Documentation**: pub.dev/packages/atomic_flutter
- **Test Files**: `../test/` for unit test examples

---

## 🎉 What's New in v0.3.0

The enhanced example showcases fixes from v0.3.0:
- ✅ **No memory leaks** - All extensions properly cleanup
- ✅ **Error isolation** - Failing listeners don't crash app
- ✅ **Computed safety** - Can't accidentally mutate computed atoms
- ✅ **Circular detection** - Prevents infinite dependency loops

---

## 🤝 Contributing

Found a bug or want to add an example? PRs welcome!

---

**Happy Coding with AtomicFlutter! 🚀**