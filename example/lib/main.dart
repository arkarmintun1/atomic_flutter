import 'package:flutter/material.dart';
import 'package:atomic_flutter/atomic_flutter.dart';

///--------------------------------------
/// Models
///--------------------------------------

/// Shopping cart model
class Cart {
  final List<CartItem> items;

  const Cart({this.items = const []});

  /// Total price of all items
  double get totalPrice => items.fold(0, (sum, item) => sum + item.totalPrice);

  /// Total number of items
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  /// Add an item to cart
  Cart addItem(CartItem item) {
    final updatedItems = List<CartItem>.from(items);
    final index =
        updatedItems.indexWhere((i) => i.product.id == item.product.id);

    if (index >= 0) {
      // Update existing item
      final existing = updatedItems[index];
      updatedItems[index] = CartItem(
        product: existing.product,
        quantity: existing.quantity + item.quantity,
      );
    } else {
      // Add new item
      updatedItems.add(item);
    }

    return Cart(items: updatedItems);
  }

  /// Remove an item from cart
  Cart removeItem(int productId) {
    return Cart(
      items: items.where((item) => item.product.id != productId).toList(),
    );
  }

  /// Update item quantity
  Cart updateQuantity(int productId, int quantity) {
    return Cart(
      items: items.map((item) {
        if (item.product.id == productId) {
          return CartItem(
            product: item.product,
            quantity: quantity,
          );
        }
        return item;
      }).toList(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Cart &&
          items.length == other.items.length &&
          _itemsEqual(items, other.items);

  bool _itemsEqual(List<CartItem> a, List<CartItem> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => items.fold(0, (hash, item) => hash ^ item.hashCode);

  @override
  String toString() => 'Cart(items: ${items.length}, total: $totalPrice)';
}

/// Product model
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

  /// Factory for empty product
  factory Product.empty() => const Product(
        id: 0,
        name: '',
        description: '',
        price: 0,
        imageUrl: '',
      );

  /// Create a copy with updated fields
  Product copyWith({
    int? id,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    bool? inStock,
    List<String>? categories,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      inStock: inStock ?? this.inStock,
      categories: categories ?? this.categories,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Product &&
          id == other.id &&
          name == other.name &&
          description == other.description &&
          price == other.price &&
          imageUrl == other.imageUrl &&
          inStock == other.inStock;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      description.hashCode ^
      price.hashCode ^
      imageUrl.hashCode ^
      inStock.hashCode;

  @override
  String toString() => 'Product(id: $id, name: $name, price: $price)';
}

/// User model
class User {
  final int id;
  final String email;
  final String name;
  final String? profilePicture;
  final bool isVerified;

  const User({
    required this.id,
    required this.email,
    required this.name,
    this.profilePicture,
    this.isVerified = false,
  });

  /// Create a copy with updated fields
  User copyWith({
    int? id,
    String? email,
    String? name,
    String? profilePicture,
    bool? isVerified,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      profilePicture: profilePicture ?? this.profilePicture,
      isVerified: isVerified ?? this.isVerified,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          id == other.id &&
          email == other.email &&
          name == other.name &&
          profilePicture == other.profilePicture &&
          isVerified == other.isVerified;

  @override
  int get hashCode =>
      id.hashCode ^
      email.hashCode ^
      name.hashCode ^
      profilePicture.hashCode ^
      isVerified.hashCode;

  @override
  String toString() => 'User(id: $id, name: $name, email: $email)';
}

///--------------------------------------
/// Atoms
///--------------------------------------

/// Theme-specific atom with integrated theme logic
class ThemeAtom extends Atom<ThemeMode> {
  ThemeAtom() : super(ThemeMode.system, id: 'theme', autoDispose: false);

  /// Set light theme
  void setLight() {
    set(ThemeMode.light);
  }

  /// Set dark theme
  void setDark() {
    set(ThemeMode.dark);
  }

  /// Set system theme
  void setSystem() {
    set(ThemeMode.system);
  }

  /// Toggle between light and dark
  void toggle() {
    update((current) =>
        current == ThemeMode.light ? ThemeMode.dark : ThemeMode.light);
  }

  /// Check if dark mode is active
  bool get isDarkMode => value == ThemeMode.dark;

  /// Check if light mode is active
  bool get isLightMode => value == ThemeMode.light;
}

/// Cart-specific atom with integrated logic
class CartAtom extends Atom<Cart> {
  final ApiService _apiService;

  CartAtom(this._apiService)
      : super(const Cart(), id: 'cart', autoDispose: false);

  /// Add a product to the cart
  void addProduct(Product product, int quantity) {
    update(
        (cart) => cart.addItem(CartItem(product: product, quantity: quantity)));
  }

  /// Remove a product from the cart
  void removeProduct(int productId) {
    update((cart) => cart.removeItem(productId));
  }

  /// Update the quantity of a product
  void updateQuantity(int productId, int quantity) {
    update((cart) => cart.updateQuantity(productId, quantity));
  }

  /// Clear all items from the cart
  void clear() {
    set(const Cart());
  }

  /// Check if a product is in the cart
  bool hasProduct(int productId) {
    return value.items.any((item) => item.product.id == productId);
  }

  /// Get the quantity of a product in the cart
  int quantityOf(int productId) {
    final item = value.items.firstWhere(
      (item) => item.product.id == productId,
      orElse: () => CartItem(product: Product.empty(), quantity: 0),
    );
    return item.quantity;
  }

  /// Save cart to backend
  Future<void> saveCart() async {
    try {
      await _apiService.saveCart(value);
    } catch (e) {
      // Error handling
      print('Error saving cart: $e');
    }
  }

  /// Load cart from backend
  Future<void> loadCart() async {
    try {
      final cart = await _apiService.getCart();
      set(cart);
    } catch (e) {
      // Error handling
      print('Error loading cart: $e');
    }
  }
}

/// User-specific atom with integrated auth logic
class UserAtom extends Atom<User?> {
  final ApiService _apiService;

  UserAtom(this._apiService) : super(null, id: 'user', autoDispose: false);

  /// Login a user
  Future<bool> login(String email, String password) async {
    try {
      final user = await _apiService.login(email, password);
      set(user);
      return true;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  /// Logout the current user
  Future<void> logout() async {
    try {
      await _apiService.logout();
      set(null);
    } catch (e) {
      print('Logout error: $e');
    }
  }

  /// Update user profile
  Future<bool> updateProfile({String? name, String? email}) async {
    if (value == null) return false;

    try {
      final updatedUser = await _apiService.updateUser(
        value!.id,
        name: name,
        email: email,
      );

      set(updatedUser);
      return true;
    } catch (e) {
      print('Update profile error: $e');
      return false;
    }
  }

  /// Check if user is logged in
  bool get isLoggedIn => value != null;
}

/// Products list atom with integrated filtering and sorting
class ProductsAtom extends Atom<List<Product>> {
  final ApiService _apiService;

  ProductsAtom(this._apiService)
      : super([], id: 'products', autoDispose: false);

  /// Load all products
  Future<void> loadProducts() async {
    try {
      final products = await _apiService.getProducts();
      set(products);
    } catch (e) {
      print('Error loading products: $e');
    }
  }

  /// Load a product by ID
  Future<Product?> loadProductById(int id) async {
    // Check if already in the list
    final existing = getById(id);
    if (existing != null) {
      return existing;
    }

    try {
      final product = await _apiService.getProduct(id);

      // Add to the list
      update((products) => [...products, product]);

      return product;
    } catch (e) {
      print('Error loading product $id: $e');
      return null;
    }
  }

  /// Get a product by ID from the current list
  Product? getById(int id) {
    try {
      return value.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Filter products by search query
  List<Product> search(String query) {
    final normalizedQuery = query.toLowerCase();
    return value
        .where((product) =>
            product.name.toLowerCase().contains(normalizedQuery) ||
            product.description.toLowerCase().contains(normalizedQuery))
        .toList();
  }

  /// Sort by price (low to high)
  List<Product> get sortByPriceLowToHigh {
    final sorted = List<Product>.from(value);
    sorted.sort((a, b) => a.price.compareTo(b.price));
    return sorted;
  }

  /// Sort by price (high to low)
  List<Product> get sortByPriceHighToLow {
    final sorted = List<Product>.from(value);
    sorted.sort((a, b) => b.price.compareTo(a.price));
    return sorted;
  }
}

/// Global atoms instances

final apiService = ApiService();

// atoms without dependencies
final mainPageTabAtom = Atom<int>(0);
final ThemeAtom themeAtom = ThemeAtom();
// atoms with dependencies
final CartAtom cartAtom = CartAtom(apiService);
final UserAtom userAtom = UserAtom(apiService);
final ProductsAtom productsAtom = ProductsAtom(apiService);

/// Computed atoms
final Atom<int> cartCountAtom = computed<int>(
  () => cartAtom.value.itemCount,
  tracked: [cartAtom],
  id: 'cart_count',
  autoDispose: false,
);

final Atom<double> cartTotalAtom = computed<double>(
  () => cartAtom.value.totalPrice,
  tracked: [cartAtom],
  id: 'cart_total',
  autoDispose: false,
);

final Atom<bool> isLoggedInAtom = computed<bool>(
  () => userAtom.value != null,
  tracked: [userAtom],
  id: 'is_logged_in',
  autoDispose: false,
);

void main() {
  // Enable debug mode during development
  enableDebugMode();

  /// Load initial app data

  // Load products in the background
  productsAtom.loadProducts();

  // Try to load the user's cart if they're logged in
  if (userAtom.isLoggedIn) {
    cartAtom.loadCart();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AtomBuilder(
      atom: themeAtom,
      builder: (context, themeMode) {
        return MaterialApp(
          title: 'AtomicFlutter Shop',
          themeMode: themeMode,
          theme: ThemeData.light(useMaterial3: true),
          darkTheme: ThemeData.dark(useMaterial3: true),
          home: const MainScreen(),
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final _tabs = const [
    ProductListTab(),
    CartTab(),
    ProfileTab(),
  ];

  @override
  Widget build(BuildContext context) {
    return AtomBuilder(
      atom: mainPageTabAtom,
      builder: (context, index) {
        return Scaffold(
          body: _tabs[index],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: index,
            onTap: (index) {
              mainPageTabAtom.set(index);
            },
            items: [
              const BottomNavigationBarItem(
                icon: Icon(Icons.home),
                label: 'Products',
              ),
              BottomNavigationBarItem(
                icon: AtomBuilder(
                  atom: cartCountAtom,
                  builder: (context, count) {
                    return Badge(
                      label: Text('$count'),
                      isLabelVisible: count > 0,
                      child: const Icon(Icons.shopping_cart),
                    );
                  },
                ),
                label: 'Cart',
              ),
              BottomNavigationBarItem(
                icon: AtomBuilder(
                  atom: userAtom,
                  builder: (context, user) => user != null
                      ? const Icon(Icons.person)
                      : const Icon(Icons.login),
                ),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

class CartTab extends StatelessWidget {
  const CartTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping Cart'),
        actions: [
          // Clear cart button
          AtomBuilder(
            atom: cartAtom,
            builder: (context, cart) {
              if (cart.items.isEmpty) return const SizedBox.shrink();

              return IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () {
                  _showClearCartDialog(context);
                },
              );
            },
          ),
        ],
      ),
      body: AtomBuilder(
        atom: cartAtom,
        builder: (context, cart) {
          if (cart.items.isEmpty) {
            return const _EmptyCart();
          }

          return _CartItemList(cart: cart);
        },
      ),
      bottomNavigationBar: AtomBuilder(
        atom: cartAtom,
        builder: (context, cart) {
          if (cart.items.isEmpty) return const SizedBox.shrink();

          return _CartSummary(cart: cart);
        },
      ),
    );
  }

  void _showClearCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Are you sure you want to clear your cart?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Clear'),
            onPressed: () {
              cartAtom.clear();
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cart cleared')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Your cart is empty',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.shopping_bag),
            label: const Text('Browse Products'),
            onPressed: () {
              mainPageTabAtom.set(0);
            },
          ),
        ],
      ),
    );
  }
}

class _CartItemList extends StatelessWidget {
  final Cart cart;

  const _CartItemList({
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: cart.items.length,
      itemBuilder: (context, index) {
        final item = cart.items[index];
        return CartItemTile(item: item);
      },
    );
  }
}

class CartItemTile extends StatelessWidget {
  final CartItem item;

  const CartItemTile({
    super.key,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final product = item.product;

    return Dismissible(
      key: Key('cart_item_${product.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (_) {
        cartAtom.removeProduct(product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} removed from cart'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                cartAtom.addProduct(product, item.quantity);
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Product image
              SizedBox(
                width: 80,
                height: 80,
                child: Image.network(
                  product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.image, size: 50),
                ),
              ),
              const SizedBox(width: 16),

              // Product details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quantity selector
                    Row(
                      children: [
                        const Text('Quantity:'),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.remove),
                          onPressed: item.quantity > 1
                              ? () => cartAtom.updateQuantity(
                                  product.id, item.quantity - 1)
                              : null,
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        Text('${item.quantity}'),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: () => cartAtom.updateQuantity(
                              product.id, item.quantity + 1),
                          iconSize: 18,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Item total
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${item.totalPrice.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final Cart cart;

  const _CartSummary({
    required this.cart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Order summary
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal:'),
                Text('\$${cart.totalPrice.toStringAsFixed(2)}'),
              ],
            ),
            const SizedBox(height: 4),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Shipping:'),
                Text('Free'),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                Text(
                  '\$${cart.totalPrice.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Checkout button
            SizedBox(
              width: double.infinity,
              child: AtomBuilder(
                atom: isLoggedInAtom,
                builder: (context, isLoggedIn) {
                  return ElevatedButton(
                    onPressed: () {
                      if (!isLoggedIn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please log in to checkout'),
                          ),
                        );
                        return;
                      }

                      // Show checkout success and clear cart
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Order Placed'),
                          content: const Text('Thank you for your order!'),
                          actions: [
                            TextButton(
                              child: const Text('OK'),
                              onPressed: () {
                                Navigator.of(context).pop();
                                cartAtom.clear();
                              },
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Checkout'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductListTab extends StatefulWidget {
  const ProductListTab({super.key});

  @override
  State<ProductListTab> createState() => _ProductListTabState();
}

class _ProductListTabState extends State<ProductListTab> {
  // Screen-specific atoms
  final searchQueryAtom = Atom<String>('');
  final sortOptionAtom = Atom<SortOption>(SortOption.nameAsc);

  // Computed atom for filtered and sorted products
  late final filteredProductsAtom = computed<List<Product>>(
    () {
      final allProducts = productsAtom.value;
      final query = searchQueryAtom.value.toLowerCase();
      final sortOption = sortOptionAtom.value;

      // Apply search filter
      var filtered = query.isEmpty
          ? List<Product>.from(allProducts)
          : allProducts
              .where((p) =>
                  p.name.toLowerCase().contains(query) ||
                  p.description.toLowerCase().contains(query))
              .toList();

      // Apply sorting
      switch (sortOption) {
        case SortOption.nameAsc:
          filtered.sort((a, b) => a.name.compareTo(b.name));
          break;
        case SortOption.nameDesc:
          filtered.sort((a, b) => b.name.compareTo(a.name));
          break;
        case SortOption.priceAsc:
          filtered.sort((a, b) => a.price.compareTo(b.price));
          break;
        case SortOption.priceDesc:
          filtered.sort((a, b) => b.price.compareTo(a.price));
          break;
      }

      return filtered;
    },
    tracked: [productsAtom, searchQueryAtom, sortOptionAtom],
  );

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    await productsAtom.loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          // Sort button
          PopupMenuButton<SortOption>(
            icon: const Icon(Icons.sort),
            onSelected: (option) => sortOptionAtom.set(option),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SortOption.nameAsc,
                child: Text('Name (A-Z)'),
              ),
              const PopupMenuItem(
                value: SortOption.nameDesc,
                child: Text('Name (Z-A)'),
              ),
              const PopupMenuItem(
                value: SortOption.priceAsc,
                child: Text('Price (Low to High)'),
              ),
              const PopupMenuItem(
                value: SortOption.priceDesc,
                child: Text('Price (High to Low)'),
              ),
            ],
          ),

          // Theme toggle
          IconButton(
            icon: AtomBuilder(
              atom: themeAtom,
              builder: (_, mode) => Icon(
                mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
              ),
            ),
            onPressed: () => themeAtom.toggle(),
          ),

          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadProducts,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) => searchQueryAtom.set(value),
            ),
          ),

          // Product list
          Expanded(
            child: AtomBuilder(
              atom: filteredProductsAtom,
              builder: (context, products) {
                if (products.isEmpty) {
                  return const Center(
                    child: Text('No products found'),
                  );
                }

                return ListView.builder(
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductCard(product: product);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    print(product.imageUrl);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: Image.network(
          product.imageUrl,
          width: 50,
          height: 50,
          errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 50),
        ),
        title: Text(product.name),
        subtitle: Text('\$${product.price.toStringAsFixed(2)}'),
        trailing: product.inStock
            ? AddToCartButton(product: product)
            : const Text('Out of Stock', style: TextStyle(color: Colors.red)),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailScreen(productId: product.id),
            ),
          );
        },
      ),
    );
  }
}

class AddToCartButton extends StatelessWidget {
  final Product product;

  const AddToCartButton({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.add_shopping_cart),
      onPressed: () {
        cartAtom.addProduct(product, 1);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${product.name} added to cart'),
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'View Cart',
              onPressed: () {
                mainPageTabAtom.set(1);
              },
            ),
          ),
        );
      },
    );
  }
}

enum SortOption {
  nameAsc,
  nameDesc,
  priceAsc,
  priceDesc,
}

class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          // Theme toggle button
          IconButton(
            icon: AtomBuilder(
              atom: themeAtom,
              builder: (context, mode) => Icon(
                  mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            ),
            onPressed: () => themeAtom.toggle(),
          ),
        ],
      ),
      body: AtomBuilder(
        atom: userAtom,
        builder: (context, user) {
          if (user == null) {
            return const _LoginView();
          }

          return _ProfileView(user: user);
        },
      ),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  _LoginViewState createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _isLoadingAtom = Atom<bool>(false);
  final _errorAtom = Atom<String?>(null);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Validation
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _errorAtom.set('Please enter email and password');
      return;
    }

    // Clear any previous errors
    _errorAtom.set(null);

    // Set loading state
    _isLoadingAtom.set(true);

    try {
      // Attempt login
      final success = await userAtom.login(
        _emailController.text,
        _passwordController.text,
      );

      if (!success) {
        _errorAtom.set('Invalid credentials');
      }
    } catch (e) {
      _errorAtom.set('Login failed: $e');
    } finally {
      _isLoadingAtom.set(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.account_circle,
            size: 80,
            color: Colors.blue,
          ),
          const SizedBox(height: 32),
          Text(
            'Login',
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Error message
          AtomBuilder(
            atom: _errorAtom,
            builder: (context, error) {
              if (error == null) return const SizedBox.shrink();

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
          ),

          // Email field
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),

          // Password field
          TextField(
            controller: _passwordController,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
              helperText: 'Enter any password',
            ),
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 32),

          // Login button
          AtomBuilder(
            atom: _isLoadingAtom,
            builder: (context, isLoading) {
              return ElevatedButton(
                onPressed: isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Login'),
              );
            },
          ),

          // Demo credentials
          const SizedBox(height: 16),
          const Text(
            'Demo: Use any email and password',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileView extends StatelessWidget {
  final User user;

  const _ProfileView({
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Profile header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue.shade100,
                    child: Text(
                      user.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  if (user.isVerified)
                    Chip(
                      label: const Text('Verified'),
                      avatar: const Icon(Icons.verified, size: 16),
                      backgroundColor: Colors.green.shade100,
                      labelStyle: TextStyle(
                        color: Colors.green.shade800,
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Account section
          Text(
            'Account',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Edit Profile'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => _EditProfileDialog(user: user),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.shopping_bag),
                  title: const Text('Order History'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Not implemented in demo')),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.location_on),
                  title: const Text('Addresses'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Not implemented in demo')),
                    );
                  },
                ),
              ],
            ),
          ),

          // Cart summary
          const SizedBox(height: 24),
          Text(
            'Shopping Cart',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AtomBuilder(
                    atom: cartAtom,
                    builder: (context, cart) {
                      if (cart.items.isEmpty) {
                        return const Text('Your cart is empty');
                      }

                      return Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Items:'),
                              Text('${cart.itemCount}'),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total:'),
                              Text(
                                '\$${cart.totalPrice.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              mainPageTabAtom.set(1);
                            },
                            child: const Text('View Cart'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Logout button
          OutlinedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    TextButton(
                      child: const Text('Logout'),
                      onPressed: () {
                        Navigator.of(context).pop();
                        userAtom.logout();
                      },
                    ),
                  ],
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _EditProfileDialog extends StatefulWidget {
  final User user;

  const _EditProfileDialog({
    required this.user,
  });

  @override
  _EditProfileDialogState createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  final _isLoadingAtom = Atom<bool>(false);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _emailController = TextEditingController(text: widget.user.email);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name and email cannot be empty')),
      );
      return;
    }

    _isLoadingAtom.set(true);

    try {
      final success = await userAtom.updateProfile(
        name: _nameController.text,
        email: _emailController.text,
      );

      if (success) {
        if (mounted) Navigator.of(context).pop();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile')),
          );
        }
      }
    } finally {
      _isLoadingAtom.set(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Profile'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
        ],
      ),
      actions: [
        TextButton(
          child: const Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        AtomBuilder(
          atom: _isLoadingAtom,
          builder: (context, isLoading) {
            return TextButton(
              onPressed: isLoading ? null : _saveProfile,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            );
          },
        ),
      ],
    );
  }
}

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  // Screen-specific atoms
  final productAtom = Atom<Product?>(null);
  final quantityAtom = Atom<int>(1);

  @override
  void initState() {
    super.initState();
    _loadProduct();
  }

  Future<void> _loadProduct() async {
    final product = await productsAtom.loadProductById(widget.productId);
    productAtom.set(product);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AtomBuilder(
          atom: productAtom,
          builder: (context, product) =>
              Text(product?.name ?? 'Product Details'),
        ),
        actions: [
          // Theme toggle
          IconButton(
            icon: AtomBuilder(
              atom: themeAtom,
              builder: (context, mode) => Icon(
                  mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode),
            ),
            onPressed: () => themeAtom.toggle(),
          ),
        ],
      ),
      body: AtomBuilder(
        atom: productAtom,
        builder: (context, product) {
          if (product == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Product image
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.network(
                    product.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.image,
                      size: 100,
                    ),
                  ),
                ),

                // Product details
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${product.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.inStock ? 'In Stock' : 'Out of Stock',
                        style: TextStyle(
                          color: product.inStock ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      // Categories
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        children: product.categories
                            .map((category) => Chip(label: Text(category)))
                            .toList(),
                      ),

                      const SizedBox(height: 16),
                      Text(product.description),

                      // Quantity selector
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          const Text('Quantity:'),
                          const SizedBox(width: 16),
                          _QuantitySelector(
                            quantityAtom: quantityAtom,
                            inStock: product.inStock,
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Cart section
                      AtomBuilder(
                        atom: cartAtom,
                        builder: (context, cart) {
                          final inCart = cartAtom.hasProduct(product.id);
                          final cartQuantity = cartAtom.quantityOf(product.id);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Show current cart status if in cart
                              if (inCart)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Text(
                                    'Currently in cart: $cartQuantity',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                              // Add to cart button
                              AtomBuilder(
                                atom: quantityAtom,
                                builder: (ctx, quantity) {
                                  return ElevatedButton(
                                    onPressed: product.inStock
                                        ? () {
                                            // Use the CartAtom's built-in method
                                            cartAtom.addProduct(
                                                product, quantity);

                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                    '${product.name} added to cart'),
                                                action: SnackBarAction(
                                                  label: 'View Cart',
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                    mainPageTabAtom.set(2);
                                                  },
                                                ),
                                              ),
                                            );
                                          }
                                        : null,
                                    child: Text(
                                        inCart ? 'Update Cart' : 'Add to Cart'),
                                  );
                                },
                              ),

                              // Remove from cart button (if in cart)
                              if (inCart)
                                TextButton(
                                  onPressed: () {
                                    // Use the CartAtom's built-in method
                                    cartAtom.removeProduct(product.id);

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            'Removed ${product.name} from cart'),
                                      ),
                                    );
                                  },
                                  child: const Text('Remove from Cart'),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final Atom<int> quantityAtom;
  final bool inStock;

  const _QuantitySelector({
    required this.quantityAtom,
    required this.inStock,
  });

  @override
  Widget build(BuildContext context) {
    return AtomBuilder(
      atom: quantityAtom,
      builder: (context, quantity) {
        return Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove),
              onPressed: quantity > 1 && inStock
                  ? () => quantityAtom.update((q) => q - 1)
                  : null,
            ),
            Text(
              '$quantity',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed:
                  inStock ? () => quantityAtom.update((q) => q + 1) : null,
            ),
          ],
        );
      },
    );
  }
}

/// Mock API service for the example app
///
/// In a real app, this would make HTTP requests to a backend server.
/// Here we're just simulating network requests with delays.
class ApiService {
  // Mock product data
  final List<Product> _products = const [
    Product(
      id: 1,
      name: 'Smartphone X',
      description: 'The latest smartphone with amazing features.',
      price: 999.99,
      imageUrl: 'https://picsum.photos/200?image=1',
      categories: ['Electronics', 'Phones'],
    ),
    Product(
      id: 2,
      name: 'Laptop Pro',
      description: 'Powerful laptop for professionals.',
      price: 1499.99,
      imageUrl: 'https://picsum.photos/200?image=2',
      categories: ['Electronics', 'Computers'],
    ),
    Product(
      id: 3,
      name: 'Wireless Headphones',
      description: 'High-quality wireless headphones with noise cancellation.',
      price: 199.99,
      imageUrl: 'https://picsum.photos/200?image=3',
      categories: ['Electronics', 'Audio'],
    ),
    Product(
      id: 4,
      name: 'Smart Watch',
      description: 'Track your fitness and stay connected.',
      price: 249.99,
      imageUrl: 'https://picsum.photos/200?image=4',
      categories: ['Electronics', 'Wearables'],
    ),
    Product(
      id: 5,
      name: 'Bluetooth Speaker',
      description: 'Portable speaker with amazing sound quality.',
      price: 129.99,
      imageUrl: 'https://picsum.photos/200?image=5',
      categories: ['Electronics', 'Audio'],
    ),
    Product(
      id: 6,
      name: 'Tablet Mini',
      description: 'Compact tablet for reading and browsing.',
      price: 349.99,
      imageUrl: 'https://picsum.photos/200?image=6',
      categories: ['Electronics', 'Computers'],
    ),
    Product(
      id: 7,
      name: 'Digital Camera',
      description: 'Capture your memories in high resolution.',
      price: 599.99,
      imageUrl: 'https://picsum.photos/200?image=7',
      categories: ['Electronics', 'Photography'],
    ),
    Product(
      id: 8,
      name: 'Gaming Console',
      description: 'Next-generation gaming experience.',
      price: 499.99,
      imageUrl: 'https://picsum.photos/200?image=8',
      categories: ['Electronics', 'Gaming'],
      inStock: false,
    ),
  ];

  // Mock user data
  User? _currentUser;

  // Mock cart data
  Cart _cart = const Cart();

  /// Get all products
  Future<List<Product>> getProducts() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));
    return _products;
  }

  /// Get a specific product by ID
  Future<Product> getProduct(int id) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    final product = _products.firstWhere(
      (p) => p.id == id,
      orElse: () => throw Exception('Product not found'),
    );

    return product;
  }

  /// Login user
  Future<User> login(String email, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // Mock authentication (in a real app, this would validate credentials)
    if (password.isEmpty) {
      throw Exception('Invalid credentials');
    }

    // Create mock user
    _currentUser = User(
      id: 1,
      email: email,
      name: email.split('@').first,
      isVerified: true,
    );

    return _currentUser!;
  }

  /// Logout user
  Future<void> logout() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    _currentUser = null;
  }

  /// Get current user
  Future<User?> getCurrentUser() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));

    return _currentUser;
  }

  /// Update user profile
  Future<User> updateUser(int userId, {String? name, String? email}) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 800));

    if (_currentUser == null) {
      throw Exception('Not logged in');
    }

    // Update user
    _currentUser = User(
      id: _currentUser!.id,
      email: email ?? _currentUser!.email,
      name: name ?? _currentUser!.name,
      profilePicture: _currentUser!.profilePicture,
      isVerified: _currentUser!.isVerified,
    );

    return _currentUser!;
  }

  /// Get cart
  Future<Cart> getCart() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    return _cart;
  }

  /// Save cart
  Future<void> saveCart(Cart cart) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 700));

    _cart = cart;
  }
}

/// Cart item model
class CartItem {
  final Product product;
  final int quantity;

  const CartItem({
    required this.product,
    required this.quantity,
  });

  /// Total price for this item
  double get totalPrice => product.price * quantity;

  /// Create a copy with updated fields
  CartItem copyWith({
    Product? product,
    int? quantity,
  }) {
    return CartItem(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CartItem &&
          product == other.product &&
          quantity == other.quantity;

  @override
  int get hashCode => product.hashCode ^ quantity.hashCode;

  @override
  String toString() =>
      'CartItem(product: ${product.name}, quantity: $quantity)';
}
