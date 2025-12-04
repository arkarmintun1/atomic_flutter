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
  - [Async State Management](#async-state-management)
    - [AsyncAtom](#asyncatom)
    - [AsyncValue](#asyncvalue)
    - [AsyncAtom Operations](#asyncatom-operations)
  - [Async Widgets](#async-widgets)
    - [AsyncAtomBuilder](#asyncatombuilder)
    - [AsyncBuilder](#asyncbuilder)
  - [Async Extensions](#async-extensions)
    - [AsyncAtom Extensions](#asyncatom-extensions)
    - [Atom to AsyncAtom Extensions](#atom-to-asyncatom-extensions)
    - [Async Computed Functions](#async-computed-functions)
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
    - [API Data Fetching](#api-data-fetching)
  - [Conclusion](#conclusion)
  - [License](#license)

## Installation

Add AtomicFlutter to your `pubspec.yaml`:

```yaml
dependencies:
  atomic_flutter: ^0.3.0
```

Then import it in your Dart files:

```dart
import 'package:atomic_flutter/atomic_flutter.dart';
```

## Core Concepts

AtomicFlutter is based on the concept of **atoms** - individual units of state that can be observed and updated. It uses a reactive programming model where UI components subscribe to atoms and automatically rebuild when the atom's value changes.

### Key Features

- 🔄 **Reactive State Management**: Automatically update UI when state changes
- ⚡ **Async State Support**: Built-in loading, success, and error states for async operations
- 🧩 **Composable Atoms**: Build complex state from simple primitives
- 🔗 **Async Chaining & Composition**: Chain async operations and combine multiple async atoms
- 🎯 **Specialized Async Widgets**: Ready-to-use widgets for common async patterns
- 🔄 **Automatic Retry & Refresh**: Built-in retry mechanisms and pull-to-refresh support  
- ⏱️ **Debouncing & Throttling**: Control async operation frequency
- 💾 **Caching & TTL**: Built-in caching with time-to-live support
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

## Async State Management

AtomicFlutter provides powerful async state management capabilities through `AsyncAtom` and `AsyncValue`. These tools make it easy to handle loading states, errors, and data in your async operations.

### AsyncAtom

`AsyncAtom` is specialized for managing asynchronous operations with built-in loading, success, and error states:

```dart
// Create an AsyncAtom
final userDataAtom = AsyncAtom<User>();

// Execute async operations
Future<void> fetchUserData() async {
  await userDataAtom.execute(() async {
    // Simulate API call
    await Future.delayed(Duration(seconds: 2));
    return User(id: 1, name: 'John Doe');
  });
}

// Execute with previous data preservation
await userDataAtom.execute(
  () => api.refreshUserData(),
  keepPreviousData: true, // Show previous data while loading
);
```

### AsyncValue

`AsyncValue` represents the state of an async operation and provides type-safe access to loading, success, and error states:

```dart
final asyncValue = userDataAtom.value;

// Check states
if (asyncValue.isLoading) {
  // Show loading spinner
} else if (asyncValue.hasError) {
  // Handle error: asyncValue.error, asyncValue.stackTrace
} else if (asyncValue.hasValue) {
  // Use data: asyncValue.value
}

// Pattern matching approach
final result = asyncValue.when(
  idle: () => 'No data loaded',
  loading: () => 'Loading...',
  success: (data) => 'Loaded: ${data.name}',
  error: (error, stackTrace) => 'Error: $error',
);

// Optional pattern matching
final result = asyncValue.maybeWhen(
  success: (data) => 'Success: ${data.name}',
  orElse: () => 'Not loaded',
);
```

### AsyncAtom Operations

```dart
// Execute and store operation for refresh capability
await userAtom.executeAndStore(() => api.fetchUser());

// Refresh the last operation
await userAtom.refresh();

// Cancel current operation
userAtom.cancel();

// Clear state back to idle
userAtom.clear();

// Set data directly (optimistic updates)
userAtom.setData(user);

// Set error state directly
userAtom.setError(exception, stackTrace);
```

## Async Widgets

AtomicFlutter provides two main widgets for working with `AsyncAtom` instances:

### AsyncAtomBuilder

Full control over all async states with custom builders:

```dart
AsyncAtomBuilder<User>(
  atom: userAtom,
  idle: (context) => Text('Press button to load'),
  loading: (context, previousData) => Column(
    children: [
      CircularProgressIndicator(),
      if (previousData != null) Text('Previous: ${previousData.name}'),
    ],
  ),
  success: (context, user) => Text('Hello ${user.name}!'),
  error: (context, error, stackTrace, previousData) => Column(
    children: [
      Text('Error: $error'),
      ElevatedButton(
        onPressed: () => userAtom.refresh(),
        child: Text('Retry'),
      ),
    ],
  ),
);
```

### AsyncBuilder

Main async builder widget with retry and refresh support:

```dart
// Basic usage with sensible defaults
AsyncBuilder<User>(
  atom: userAtom,
  builder: (context, user) => Text('Hello ${user.name}!'),
  // Optional custom widgets
  loading: (context) => Text('Custom loading...'),
  error: (context, error) => Text('Custom error: $error'),
  idle: (context) => Text('Custom idle state'),
);

// With retry functionality
AsyncBuilder<String>(
  atom: dataAtom,
  builder: (context, data) => Text('Data: $data'),
  enableRetry: true,
  retryOperation: () => api.fetchData(),
  // Optional custom retry error widget
  customRetryError: (context, error, retry) => Column(
    children: [
      Text('Error: $error'),
      ElevatedButton(
        onPressed: retry,
        child: Text('Try Again'),
      ),
    ],
  ),
);

// With pull-to-refresh support  
AsyncBuilder<List<Post>>(
  atom: postsAtom,
  builder: (context, posts) => ListView.builder(
    itemCount: posts.length,
    itemBuilder: (context, index) => ListTile(
      title: Text(posts[index].title),
    ),
  ),
  enableRefresh: true,
  onRefresh: () => api.fetchPosts(),
);

// Combine retry and refresh
AsyncBuilder<List<Post>>(
  atom: postsAtom,
  builder: (context, posts) => ListView.builder(
    itemCount: posts.length,
    itemBuilder: (context, index) => ListTile(
      title: Text(posts[index].title),
    ),
  ),
  enableRetry: true,
  retryOperation: () => api.fetchPosts(),
  enableRefresh: true,
  onRefresh: () => api.refreshPosts(),
);
```

## Async Extensions

### AsyncAtom Extensions

Powerful extensions for AsyncAtom instances:

```dart
// Debounce async operations
final debouncedSearchAtom = searchResultsAtom.debounceAsync(
  Duration(milliseconds: 300)
);

// Map success values to another type
final userNamesAtom = usersAtom.mapAsync((users) => 
  users.map((user) => user.name).toList()
);

// Execute only if not currently loading
await dataAtom.executeIfNotLoading(() => api.fetchData());

// Execute with automatic retry
await dataAtom.executeWithRetry(
  () => api.fetchData(),
  maxRetries: 3,
  delay: Duration(seconds: 1), // Exponential backoff
);

// Chain async operations
final processedDataAtom = rawDataAtom.chain((data) async {
  return await processData(data);
});

// Create cached version with TTL
final cachedDataAtom = dataAtom.cached(
  ttl: Duration(minutes: 5),
  refreshOnError: true,
);
```

### Atom to AsyncAtom Extensions

Convert regular atoms to async atoms:

```dart
// Convert regular atom to AsyncAtom
final asyncUserAtom = userAtom.toAsync();

// Create async atom that executes when regular atom changes
final userPostsAtom = userIdAtom.asyncMap((userId) async {
  return await api.fetchUserPosts(userId);
});
```

### Async Computed Functions

Create computed async atoms:

```dart
// Create async computed atom
final userProfileAtom = computedAsync<UserProfile>(
  () async {
    final user = userAtom.value;
    final settings = settingsAtom.value;
    return await api.buildUserProfile(user, settings);
  },
  tracked: [userAtom, settingsAtom],
  debounce: Duration(milliseconds: 500), // Debounce computations
);

// Combine multiple async atoms
final combinedDataAtom = combineAsync([
  userDataAtom,
  settingsDataAtom,
  preferencesAtom,
]);

// Access combined results
combinedDataAtom.value.when(
  success: (dataList) {
    final userData = dataList[0];
    final settingsData = dataList[1];
    final preferences = dataList[2];
    // Use all data together
  },
  loading: () => showLoading(),
  error: (error, _) => showError(error),
  idle: () => showIdle(),
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

### API Data Fetching

Complete example of async data fetching with error handling and caching:

```dart
// API service
class ApiService {
  static const baseUrl = 'https://api.example.com';
  
  Future<List<Post>> fetchPosts() async {
    final response = await http.get(Uri.parse('$baseUrl/posts'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((json) => Post.fromJson(json)).toList();
    }
    throw Exception('Failed to load posts');
  }

  Future<Post> fetchPost(int id) async {
    final response = await http.get(Uri.parse('$baseUrl/posts/$id'));
    if (response.statusCode == 200) {
      return Post.fromJson(json.decode(response.body));
    }
    throw Exception('Failed to load post');
  }
}

// Atoms for posts management
final postsAtom = AsyncAtom<List<Post>>(autoDispose: false);
final selectedPostAtom = Atom<Post?>(null);

// Computed async atom for selected post details
final postDetailsAtom = computedAsync<PostDetails?>(
  () async {
    final post = selectedPostAtom.value;
    if (post == null) return null;
    
    // Fetch additional details for the selected post
    return await ApiService().fetchPostDetails(post.id);
  },
  tracked: [selectedPostAtom],
  debounce: Duration(milliseconds: 300),
);

// Posts list widget
class PostsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Posts')),
      body: AsyncBuilder<List<Post>>(
        atom: postsAtom,
        enableRefresh: true,
        onRefresh: () => ApiService().fetchPosts(),
        builder: (context, posts) => ListView.builder(
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return AtomBuilder<Post?>(
              atom: selectedPostAtom,
              builder: (context, selectedPost) => ListTile(
                title: Text(post.title),
                subtitle: Text(post.excerpt),
                selected: selectedPost?.id == post.id,
                onTap: () => selectedPostAtom.set(post),
              ),
            );
          },
        ),
        loading: (context) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading posts...'),
            ],
          ),
        ),
        error: (context, error) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text('Failed to load posts: $error'),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => postsAtom.refresh(),
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Refresh posts with exponential backoff retry
          postsAtom.executeWithRetry(
            () => ApiService().fetchPosts(),
            maxRetries: 3,
            delay: Duration(seconds: 1),
          );
        },
        child: Icon(Icons.refresh),
      ),
    );
  }
}

// Post details widget
class PostDetails extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AtomBuilder<Post?>(
      atom: selectedPostAtom,
      builder: (context, selectedPost) {
        if (selectedPost == null) {
          return Center(child: Text('Select a post to view details'));
        }

        return AsyncBuilder<PostDetails?>(
          atom: postDetailsAtom,
          builder: (context, details) {
            if (details == null) return SizedBox();
            
            return Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedPost.title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  SizedBox(height: 16),
                  Text(details.content),
                  SizedBox(height: 16),
                  Text(
                    'Comments: ${details.commentCount}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// App initialization
void main() {
  runApp(MyApp());
  
  // Load initial posts on app start
  postsAtom.executeAndStore(() => ApiService().fetchPosts());
}
```

See the [example folder](example/) for a full e-commerce app demo.

## Conclusion

AtomicFlutter provides a comprehensive, lightweight, and type-safe state management solution for Flutter applications. With its powerful async capabilities, specialized widgets, and extensive extension system, it handles everything from simple state management to complex async operations.

Key strengths:

- **Complete Async Support**: From basic loading states to advanced retry mechanisms and caching
- **Widget Ecosystem**: Specialized widgets for every async pattern you'll encounter
- **Developer Experience**: Type-safe APIs, automatic memory management, and powerful debugging tools
- **Production Ready**: Built-in error handling, retry logic, and performance optimizations
- **Flexible Architecture**: Works equally well for simple apps and complex enterprise applications

Whether you're building a simple counter app, a data-heavy dashboard, or a complex e-commerce application with real-time updates, AtomicFlutter's flexible API and comprehensive feature set make it an excellent choice for modern Flutter development.

For more detailed examples and advanced usage patterns, check out the example applications included in the package.

## License

[MIT License](LICENSE)
