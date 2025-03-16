import 'package:atomic_flutter/atomic_flutter.dart';
import 'domain_atoms.dart';
import '../services/api_service.dart';

/// Global atoms instances
late final CartAtom cartAtom;
late final UserAtom userAtom;
late final ThemeAtom themeAtom;
late final ProductsAtom productsAtom;

/// Computed atoms
late final Atom<int> cartCountAtom;
late final Atom<double> cartTotalAtom;
late final Atom<bool> isLoggedInAtom;

/// Initialize all global state
void initializeAppState() {
  // Create API service
  final apiService = ApiService();

  // Initialize domain-specific atoms
  cartAtom = CartAtom(apiService);
  userAtom = UserAtom(apiService);
  themeAtom = ThemeAtom();
  productsAtom = ProductsAtom(apiService);

  // Setup computed atoms
  cartCountAtom = computed<int>(
    () => cartAtom.value.itemCount,
    tracked: [cartAtom],
    id: 'cart_count',
    autoDispose: false,
  );

  cartTotalAtom = computed<double>(
    () => cartAtom.value.totalPrice,
    tracked: [cartAtom],
    id: 'cart_total',
    autoDispose: false,
  );

  isLoggedInAtom = computed<bool>(
    () => userAtom.value != null,
    tracked: [userAtom],
    id: 'is_logged_in',
    autoDispose: false,
  );

  // Load initial data
  _loadInitialData();
}

/// Load initial app data
Future<void> _loadInitialData() async {
  // Load products in the background
  productsAtom.loadProducts();

  // Try to load the user's cart if they're logged in
  if (userAtom.isLoggedIn) {
    cartAtom.loadCart();
  }
}
