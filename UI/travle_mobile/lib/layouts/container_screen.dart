import 'package:travle_mobile/providers/cart_provider.dart';
import 'package:travle_mobile/screens/cart_list_screen.dart';
import 'package:travle_mobile/screens/category_list_screen.dart';
import 'package:travle_mobile/screens/product_list_screen.dart';
import 'package:travle_mobile/screens/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ContainerScreen extends StatefulWidget {
  const ContainerScreen({super.key});

  @override
  State<ContainerScreen> createState() => _ContainerScreenState();
}

class _ContainerScreenState extends State<ContainerScreen> {
  int _selectedIndex = 0;
  bool isIndexStacked = false;
  int _previousCartCount = 0;
  late CartProvider _cartProvider;

  @override
  void initState() {
    super.initState();
    _cartProvider = Provider.of<CartProvider>(context, listen: false);
    _previousCartCount = _totalQuantity(_cartProvider);
    _cartProvider.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cartProvider.removeListener(_onCartChanged);
    super.dispose();
  }

  int _totalQuantity(CartProvider cartProvider) {
    return cartProvider.cart.items.fold(0, (sum, item) => sum + item.quantity);
  }

  void _onCartChanged() {
    final newCount = _totalQuantity(_cartProvider);
    if (newCount > _previousCartCount) {
      print('Item added to cart. Total items in cart: $newCount');
    }
    setState(() {
      _previousCartCount = newCount;
    });
  }

  List<Widget> get _widgetOptions => [
    ProductListScreen(),
    CategoryListScreen(),
    CartListScreen(onGoToHome: () => _onItemTapped(0)),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isIndexStacked
          ? IndexedStack(index: _selectedIndex, children: _widgetOptions)
          : _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        items: <BottomNavigationBarItem>[
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          const BottomNavigationBarItem(
            icon: Icon(Icons.category),
            label: 'Categories',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              _previousCartCount > 0
                  ? Icons.shopping_cart
                  : Icons.shopping_cart_outlined,
            ),
            label: 'Cart',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
