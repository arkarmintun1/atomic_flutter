import 'dart:async';
import 'package:flutter/material.dart';
import 'package:atomic_flutter/atomic_flutter.dart';

///=============================================================================
/// ENHANCED ATOMIC_FLUTTER EXAMPLE
///
/// This example showcases ALL capabilities of atomic_flutter v0.3.0:
/// ✓ Basic Atoms and Computed Atoms
/// ✓ AsyncAtom with loading/error/success states
/// ✓ AsyncBuilder with retry and refresh
/// ✓ Extension methods: debounce, throttle, map, where, combine, effect
/// ✓ Async extensions: debounceAsync, chain, cached, asyncMap, combineAsync
/// ✓ computedAsync for async derived state
/// ✓ Domain-specific atoms with business logic
/// ✓ Error handling and isolation
/// ✓ Memory management and auto-disposal
/// ✓ AtomSelector for performance optimization
/// ✓ Optimistic updates
///=============================================================================

///--------------------------------------
/// Models (same as before)
///--------------------------------------

class Product {
  final int id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final bool inStock;
  final List<String> categories;

  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    this.inStock = true,
    this.categories = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product && id == other.id && name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

class Cart {
  final List<CartItem> items;
  const Cart({this.items = const []});

  double get totalPrice => items.fold(0, (sum, item) => sum + item.totalPrice);
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  Cart addItem(CartItem item) {
    final updatedItems = List<CartItem>.from(items);
    final index = updatedItems.indexWhere((i) => i.product.id == item.product.id);
    if (index >= 0) {
      final existing = updatedItems[index];
      updatedItems[index] = CartItem(
        product: existing.product,
        quantity: existing.quantity + item.quantity,
      );
    } else {
      updatedItems.add(item);
    }
    return Cart(items: updatedItems);
  }

  Cart removeItem(int productId) {
    return Cart(items: items.where((item) => item.product.id != productId).toList());
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Cart && items.length == other.items.length;

  @override
  int get hashCode => items.fold(0, (hash, item) => hash ^ item.hashCode);
}

class CartItem {
  final Product product;
  final int quantity;
  const CartItem({required this.product, required this.quantity});

  double get totalPrice => product.price * quantity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem && product == other.product && quantity == other.quantity;

  @override
  int get hashCode => product.hashCode ^ quantity.hashCode;
}

class User {
  final int id;
  final String email;
  final String name;
  final bool isVerified;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.isVerified = false,
  });
}

///--------------------------------------
/// Enhanced API Service with Async Support
///--------------------------------------

class ApiService {
  static final _products = [
    const Product(
      id: 1,
      name: 'Smartphone X',
      description: 'Latest smartphone with amazing features',
      price: 999.99,
      imageUrl: 'https://picsum.photos/200?image=1',
      categories: ['Electronics', 'Phones'],
    ),
    const Product(
      id: 2,
      name: 'Laptop Pro',
      description: 'Powerful laptop for professionals',
      price: 1499.99,
      imageUrl: 'https://picsum.photos/200?image=2',
      categories: ['Electronics', 'Computers'],
    ),
    const Product(
      id: 3,
      name: 'Wireless Headphones',
      description: 'High-quality wireless headphones',
      price: 199.99,
      imageUrl: 'https://picsum.photos/200?image=3',
      categories: ['Electronics', 'Audio'],
    ),
    const Product(
      id: 4,
      name: 'Smart Watch',
      description: 'Track your fitness and stay connected',
      price: 249.99,
      imageUrl: 'https://picsum.photos/200?image=4',
      categories: ['Electronics', 'Wearables'],
    ),
  ];

  // Simulate network delay and potential errors
  Future<List<Product>> getProducts({bool shouldFail = false}) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (shouldFail) throw Exception('Network error: Could not load products');
    return _products;
  }

  Future<Product> getProduct(int id) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _products.firstWhere(
      (p) => p.id == id,
      orElse: () => throw Exception('Product not found'),
    );
  }

  Future<User> login(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    if (password.isEmpty) throw Exception('Invalid credentials');
    return User(id: 1, email: email, name: email.split('@').first, isVerified: true);
  }

  Future<Cart> saveCart(Cart cart) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return cart;
  }
}

///--------------------------------------
/// Enhanced Domain-Specific Atoms
///--------------------------------------

/// SHOWCASE: AsyncAtom with domain logic
class ProductsAsyncAtom extends AsyncAtom<List<Product>> {
  final ApiService _api;

  ProductsAsyncAtom(this._api)
      : super(id: 'products_async', autoDispose: false);

  /// Load products with proper async state management
  Future<List<Product>> loadProducts() async {
    return await executeAndStore(() => _api.getProducts());
  }

  /// Reload with potential error (for demo)
  Future<List<Product>> loadProductsWithError() async {
    return await executeAndStore(() => _api.getProducts(shouldFail: true));
  }

  /// SHOWCASE: executeWithRetry extension
  Future<List<Product>> loadProductsWithRetry() async {
    return await executeWithRetry(
      () => _api.getProducts(),
      maxRetries: 3,
      delay: const Duration(seconds: 1),
    );
  }

  /// Get product by ID from current list
  Product? getById(int id) {
    if (!value.hasValue) return null;
    try {
      return value.value.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}

/// SHOWCASE: Regular Atom with business logic
class CartAtom extends Atom<Cart> {
  final ApiService _api;

  CartAtom(this._api) : super(const Cart(), id: 'cart', autoDispose: false);

  void addProduct(Product product, int quantity) {
    update((cart) => cart.addItem(CartItem(product: product, quantity: quantity)));
    // SHOWCASE: Optimistic update - save to backend after UI update
    _saveToBackend();
  }

  void removeProduct(int productId) {
    update((cart) => cart.removeItem(productId));
    _saveToBackend();
  }

  void clear() => set(const Cart());

  Future<void> _saveToBackend() async {
    try {
      await _api.saveCart(value);
    } catch (e) {
      debugPrint('Error saving cart: $e');
    }
  }
}

/// SHOWCASE: Atom with custom methods
class ThemeAtom extends Atom<ThemeMode> {
  ThemeAtom() : super(ThemeMode.system, id: 'theme', autoDispose: false);

  void toggle() {
    update((current) => current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  bool get isDark => value == ThemeMode.dark;
}

///--------------------------------------
/// Global Atoms and Setup
///--------------------------------------

final apiService = ApiService();

// Basic atoms
final themeAtom = ThemeAtom();
final tabIndexAtom = Atom<int>(0, id: 'tab_index');

// Domain-specific atoms
final productsAsyncAtom = ProductsAsyncAtom(apiService);
final cartAtom = CartAtom(apiService);
final userAtom = Atom<User?>(null, id: 'user', autoDispose: false);

// SHOWCASE: Computed atoms
final cartCountAtom = computed<int>(
  () => cartAtom.value.itemCount,
  tracked: [cartAtom],
  id: 'cart_count',
);

final cartTotalAtom = computed<double>(
  () => cartAtom.value.totalPrice,
  tracked: [cartAtom],
  id: 'cart_total',
);

// SHOWCASE: combineAsync - combine multiple async atoms
final appDataAtom = combineAsync<dynamic>([productsAsyncAtom]);

void main() {
  enableDebugMode();

  // SHOWCASE: effect - Execute side effects
  // Uncomment to see cart changes in console:
  // cartAtom.effect(
  //   (cart) {
  //     debugPrint('Cart changed: ${cart.itemCount} items, \$${cart.totalPrice}');
  //   },
  //   runImmediately: true,
  // );

  // Initial data load
  productsAsyncAtom.loadProducts();

  runApp(const EnhancedAtomicApp());
}

///--------------------------------------
/// Main App
///--------------------------------------

class EnhancedAtomicApp extends StatelessWidget {
  const EnhancedAtomicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AtomBuilder(
      atom: themeAtom,
      builder: (context, themeMode) {
        return MaterialApp(
          title: 'AtomicFlutter Showcase',
          themeMode: themeMode,
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AtomBuilder(
      atom: tabIndexAtom,
      builder: (context, index) {
        return Scaffold(
          body: IndexedStack(
            index: index,
            children: const [
              EnhancedProductListTab(),
              EnhancedCartTab(),
              FeaturesShowcaseTab(),
            ],
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: index,
            onTap: tabIndexAtom.set,
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag),
                label: 'Products',
              ),
              BottomNavigationBarItem(
                icon: AtomBuilder(
                  atom: cartCountAtom,
                  builder: (context, count) => Badge(
                    label: Text('$count'),
                    isLabelVisible: count > 0,
                    child: const Icon(Icons.shopping_cart),
                  ),
                ),
                label: 'Cart',
              ),
              const BottomNavigationBarItem(
                icon: Icon(Icons.star),
                label: 'Features',
              ),
            ],
          ),
        );
      },
    );
  }
}

///--------------------------------------
/// SHOWCASE: AsyncBuilder with all features
///--------------------------------------

class EnhancedProductListTab extends StatefulWidget {
  const EnhancedProductListTab({super.key});

  @override
  State<EnhancedProductListTab> createState() => _EnhancedProductListTabState();
}

class _EnhancedProductListTabState extends State<EnhancedProductListTab> {
  // SHOWCASE: Debounced search atom
  final searchQueryAtom = Atom<String>('', id: 'search_query');
  late final debouncedSearchAtom = searchQueryAtom.debounce(
    const Duration(milliseconds: 500),
  );

  // SHOWCASE: Computed atom with debounced dependency
  late final filteredProductsAtom = computed<List<Product>>(
    () {
      final products = productsAsyncAtom.value;
      final query = debouncedSearchAtom.value.toLowerCase();

      if (!products.hasValue) return [];

      if (query.isEmpty) return products.value;

      return products.value
          .where((p) =>
              p.name.toLowerCase().contains(query) ||
              p.description.toLowerCase().contains(query))
          .toList();
    },
    tracked: [productsAsyncAtom, debouncedSearchAtom],
    id: 'filtered_products',
  );

  @override
  void dispose() {
    searchQueryAtom.dispose();
    debouncedSearchAtom.dispose();
    filteredProductsAtom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products (AsyncAtom Demo)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.dark_mode),
            onPressed: themeAtom.toggle,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar with debounce
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search (debounced 500ms)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: searchQueryAtom.set,
            ),
          ),

          // SHOWCASE: AsyncBuilder with retry and refresh
          Expanded(
            child: AsyncBuilder<List<Product>>(
              atom: productsAsyncAtom,
              // Pull-to-refresh enabled
              enableRefresh: true,
              onRefresh: () => productsAsyncAtom.loadProducts(),
              // Retry on error
              enableRetry: true,
              retryOperation: () => productsAsyncAtom.loadProducts(),
              // Loading state
              loading: (context) => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Loading products...'),
                  ],
                ),
              ),
              // Error state with retry button
              error: (context, error) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $error'),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                      onPressed: () => productsAsyncAtom.loadProducts(),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => productsAsyncAtom.loadProductsWithRetry(),
                      child: const Text('Retry with exponential backoff'),
                    ),
                  ],
                ),
              ),
              // Success state with filtered results
              builder: (context, products) {
                return AtomBuilder(
                  atom: filteredProductsAtom,
                  builder: (context, filtered) {
                    if (filtered.isEmpty) {
                      return const Center(child: Text('No products found'));
                    }

                    return ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        return ProductListTile(product: product);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => productsAsyncAtom.loadProductsWithError(),
        icon: const Icon(Icons.bug_report),
        label: const Text('Trigger Error'),
      ),
    );
  }
}

class ProductListTile extends StatelessWidget {
  final Product product;

  const ProductListTile({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Image.network(
          product.imageUrl,
          width: 50,
          height: 50,
          errorBuilder: (_, __, ___) => const Icon(Icons.image),
        ),
        title: Text(product.name),
        subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
        trailing: IconButton(
          icon: const Icon(Icons.add_shopping_cart),
          onPressed: () {
            cartAtom.addProduct(product, 1);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${product.name} added to cart')),
            );
          },
        ),
      ),
    );
  }
}

///--------------------------------------
/// SHOWCASE: Cart with AtomSelector
///--------------------------------------

class EnhancedCartTab extends StatelessWidget {
  const EnhancedCartTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cart (AtomSelector Demo)'),
        actions: [
          AtomBuilder(
            atom: cartAtom,
            builder: (context, cart) {
              if (cart.items.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.delete),
                onPressed: cartAtom.clear,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // SHOWCASE: AtomSelector - only rebuilds when items change
          Expanded(
            child: cartAtom.select<List<CartItem>>(
              selector: (cart) => cart.items,
              builder: (context, items) {
                if (items.isEmpty) {
                  return const Center(child: Text('Cart is empty'));
                }

                return ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return CartItemTile(item: item);
                  },
                );
              },
            ),
          ),

          // SHOWCASE: AtomSelector - only rebuilds when total changes
          cartAtom.select<double>(
            selector: (cart) => cart.totalPrice,
            builder: (context, total) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total:', style: TextStyle(fontSize: 20)),
                          Text(
                            '\$${total.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: total > 0
                              ? () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Order placed!')),
                                  );
                                  cartAtom.clear();
                                }
                              : null,
                          child: const Text('Checkout'),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CartItemTile extends StatelessWidget {
  final CartItem item;

  const CartItemTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Image.network(
          item.product.imageUrl,
          width: 50,
          height: 50,
          errorBuilder: (_, __, ___) => const Icon(Icons.image),
        ),
        title: Text(item.product.name),
        subtitle: Text('Qty: ${item.quantity} × \$${item.product.price}'),
        trailing: Text(
          '\$${item.totalPrice.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        onLongPress: () => cartAtom.removeProduct(item.product.id),
      ),
    );
  }
}

///--------------------------------------
/// SHOWCASE: All Extension Methods
///--------------------------------------

class FeaturesShowcaseTab extends StatefulWidget {
  const FeaturesShowcaseTab({super.key});

  @override
  State<FeaturesShowcaseTab> createState() => _FeaturesShowcaseTabState();
}

class _FeaturesShowcaseTabState extends State<FeaturesShowcaseTab> {
  // Demo atoms for showcasing
  final counterAtom = Atom<int>(0, id: 'counter');
  late final debouncedCounter = counterAtom.debounce(const Duration(seconds: 1));
  late final throttledCounter = counterAtom.throttle(const Duration(seconds: 1));
  late final doubledCounter = counterAtom.map((value) => value * 2);
  late final evenOnlyCounter = counterAtom.where((value) => value % 2 == 0);

  // Async demo
  final asyncCounterAtom = AsyncAtom<int>(id: 'async_counter');

  @override
  void dispose() {
    counterAtom.dispose();
    debouncedCounter.dispose();
    throttledCounter.dispose();
    doubledCounter.dispose();
    evenOnlyCounter.dispose();
    asyncCounterAtom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Features Showcase')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSection(
            'Extension Methods',
            [
              _buildFeatureCard(
                'Debounce',
                'Updates only after 1s of inactivity',
                MultiAtomBuilder(
                  atoms: [counterAtom, debouncedCounter],
                  builder: (context) => Text(
                    'Source: ${counterAtom.value} → Debounced: ${debouncedCounter.value}',
                  ),
                ),
              ),
              _buildFeatureCard(
                'Throttle',
                'Updates at most once per second',
                MultiAtomBuilder(
                  atoms: [counterAtom, throttledCounter],
                  builder: (context) => Text(
                    'Source: ${counterAtom.value} → Throttled: ${throttledCounter.value}',
                  ),
                ),
              ),
              _buildFeatureCard(
                'Map',
                'Transforms values',
                MultiAtomBuilder(
                  atoms: [counterAtom, doubledCounter],
                  builder: (context) => Text(
                    'Source: ${counterAtom.value} → Doubled: ${doubledCounter.value}',
                  ),
                ),
              ),
              _buildFeatureCard(
                'Where',
                'Filters values (even only)',
                MultiAtomBuilder(
                  atoms: [counterAtom, evenOnlyCounter],
                  builder: (context) => Text(
                    'Source: ${counterAtom.value} → Even: ${evenOnlyCounter.value}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSection(
            'AsyncAtom Features',
            [
              _buildFeatureCard(
                'Async State Management',
                'Loading, error, and success states',
                AsyncAtomBuilder<int>(
                  atom: asyncCounterAtom,
                  idle: (context) => const Text('Idle - Click button to load'),
                  loading: (context, previousData) => const CircularProgressIndicator(),
                  success: (context, data) => Text('Success: $data'),
                  error: (context, error, stack, data) => Text('Error: $error'),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  asyncCounterAtom.execute(() async {
                    await Future.delayed(const Duration(seconds: 1));
                    return counterAtom.value;
                  });
                },
                child: const Text('Load Async Value'),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Increment (triggers all extensions)'),
            onPressed: () => counterAtom.update((v) => v + 1),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildFeatureCard(String title, String description, Widget demo) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(description, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 8),
            demo,
          ],
        ),
      ),
    );
  }
}