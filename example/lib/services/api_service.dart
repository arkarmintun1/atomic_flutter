import 'dart:async';
import '../models/user.dart';
import '../models/product.dart';
import '../models/cart.dart';

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
      imageUrl: 'https://via.placeholder.com/200?text=Phone',
      categories: ['Electronics', 'Phones'],
    ),
    Product(
      id: 2,
      name: 'Laptop Pro',
      description: 'Powerful laptop for professionals.',
      price: 1499.99,
      imageUrl: 'https://via.placeholder.com/200?text=Laptop',
      categories: ['Electronics', 'Computers'],
    ),
    Product(
      id: 3,
      name: 'Wireless Headphones',
      description: 'High-quality wireless headphones with noise cancellation.',
      price: 199.99,
      imageUrl: 'https://via.placeholder.com/200?text=Headphones',
      categories: ['Electronics', 'Audio'],
    ),
    Product(
      id: 4,
      name: 'Smart Watch',
      description: 'Track your fitness and stay connected.',
      price: 249.99,
      imageUrl: 'https://via.placeholder.com/200?text=Watch',
      categories: ['Electronics', 'Wearables'],
    ),
    Product(
      id: 5,
      name: 'Bluetooth Speaker',
      description: 'Portable speaker with amazing sound quality.',
      price: 129.99,
      imageUrl: 'https://via.placeholder.com/200?text=Speaker',
      categories: ['Electronics', 'Audio'],
    ),
    Product(
      id: 6,
      name: 'Tablet Mini',
      description: 'Compact tablet for reading and browsing.',
      price: 349.99,
      imageUrl: 'https://via.placeholder.com/200?text=Tablet',
      categories: ['Electronics', 'Computers'],
    ),
    Product(
      id: 7,
      name: 'Digital Camera',
      description: 'Capture your memories in high resolution.',
      price: 599.99,
      imageUrl: 'https://via.placeholder.com/200?text=Camera',
      categories: ['Electronics', 'Photography'],
    ),
    Product(
      id: 8,
      name: 'Gaming Console',
      description: 'Next-generation gaming experience.',
      price: 499.99,
      imageUrl: 'https://via.placeholder.com/200?text=Console',
      categories: ['Electronics', 'Gaming'],
      inStock: false,
    ),
  ];

  // Mock user data
  User? _currentUser;

  // Mock cart data
  Cart _cart = Cart();

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
