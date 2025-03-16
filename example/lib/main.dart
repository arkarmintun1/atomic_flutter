import 'package:flutter/material.dart';
import 'package:atomic_flutter/atomic_flutter.dart';
import 'state/app_state.dart';
import 'screens/product_list_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  // Enable debug mode during development
  enableDebugMode();

  // Initialize app state
  initializeAppState();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

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
          routes: {
            '/cart': (context) => const CartScreen(),
            '/profile': (context) => const ProfileScreen(),
          },
        );
      },
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final _screens = const [
    ProductListScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: _CartBadge(),
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
  }
}

class _CartBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AtomBuilder(
      atom: cartCountAtom,
      builder: (context, count) {
        return Badge(
          label: Text('$count'),
          isLabelVisible: count > 0,
          child: const Icon(Icons.shopping_cart),
        );
      },
    );
  }
}
