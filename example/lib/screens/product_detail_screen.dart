import 'package:flutter/material.dart';
import 'package:atomic_flutter/atomic_flutter.dart';
import '../models/product.dart';
import '../state/app_state.dart';

class ProductDetailScreen extends StatefulWidget {
  final int productId;

  const ProductDetailScreen({
    Key? key,
    required this.productId,
  }) : super(key: key);

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
                                builder: (context, quantity) {
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
                                                    Navigator.pushNamed(
                                                        context, '/cart');
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
    Key? key,
    required this.quantityAtom,
    required this.inStock,
  }) : super(key: key);

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
