import 'product.dart';

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
