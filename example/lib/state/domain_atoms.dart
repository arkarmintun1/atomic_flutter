import 'package:flutter/material.dart';
import 'package:atomic_flutter/atomic_flutter.dart';
import '../models/cart.dart';
import '../models/product.dart';
import '../models/user.dart';
import '../services/api_service.dart';

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
