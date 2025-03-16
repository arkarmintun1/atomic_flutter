import 'package:flutter/material.dart';
import 'package:atomic_flutter/atomic_flutter.dart';
import '../state/app_state.dart';
import '../models/product.dart';
import 'product_detail_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({Key? key}) : super(key: key);

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
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
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
    Key? key,
    required this.product,
  }) : super(key: key);

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
                Navigator.pushNamed(context, '/cart');
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
