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
