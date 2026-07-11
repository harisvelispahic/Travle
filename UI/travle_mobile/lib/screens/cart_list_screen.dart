import 'package:travle_mobile/providers/auth_provider.dart';
import 'package:travle_mobile/providers/cart_provider.dart';
import 'package:travle_mobile/providers/order_provider.dart';
import 'package:travle_mobile/screens/order_detail_screen.dart';
import 'package:travle_mobile/utils/api_client_exception.dart';
import 'package:travle_mobile/utils/utils_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CartListScreen extends StatefulWidget {
  final VoidCallback? onGoToHome;

  const CartListScreen({super.key, this.onGoToHome});

  @override
  State<CartListScreen> createState() => _CartListScreenState();
}

class _CartListScreenState extends State<CartListScreen> {
  late CartProvider _cartProvider;
  bool _checkoutBusy = false;

  @override
  void initState() {
    super.initState();
    _cartProvider = context.read<CartProvider>();
  }

  double _subtotal(CartProvider cart) {
    return cart.cart.items.fold<double>(
      0,
      (sum, item) => sum + (item.product.price ?? 0) * item.quantity,
    );
  }

  Future<void> _checkout() async {
    if (AuthProvider.accesstoken == null || AuthProvider.accesstoken!.isEmpty) {
      alertBox(context, 'Login required', 'Please log in to place an order.');
      return;
    }

    if (_cartProvider.cart.items.isEmpty) {
      return;
    }

    final invalid = _cartProvider.cart.items
        .where((e) => e.product.id == null)
        .toList();
    if (invalid.isNotEmpty) {
      alertBox(context, 'Cart error', 'Some items are missing a product id.');
      return;
    }

    setState(() => _checkoutBusy = true);
    try {
      final payload = _cartProvider.cart.items
          .map(
            (e) => <String, dynamic>{
              'productId': e.product.id,
              'quantity': e.quantity,
            },
          )
          .toList();
      final order = await context.read<OrderProvider>().checkout(payload);

      _cartProvider.clearCart();

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => OrderDetailScreen(orderId: order.id),
        ),
      );
    } on ApiClientException catch (e) {
      if (mounted) {
        alertBox(context, 'Order could not be placed', e.message);
      }
    } on Exception catch (e) {
      if (mounted) {
        alertBox(context, 'Checkout', e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _checkoutBusy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, CartProvider cartProvider, child) {
        return SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildItemList()),
              if (cartProvider.cart.items.isNotEmpty)
                _buildFooter(cartProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFooter(CartProvider cartProvider) {
    final total = _subtotal(cartProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estimated total', style: TextStyle(fontSize: 16)),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: _checkoutBusy ? null : _checkout,
              child: _checkoutBusy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Place order'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    if (_cartProvider.cart.items.isEmpty) {
      return _buildEmptyCart();
    }
    return ListView.builder(
      itemCount: _cartProvider.cart.items.length,
      itemBuilder: (context, index) {
        var cartItem = _cartProvider.cart.items[index];
        return ListTile(
          title: Text(cartItem.product.name ?? ""),
          subtitle: Text('Quantity: ${cartItem.quantity}'),
          trailing: IconButton(
            icon: Icon(Icons.remove_shopping_cart),
            onPressed: () {
              _cartProvider.removeFromCart(cartItem.product);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyCart() {
    return GestureDetector(
      onTap: widget.onGoToHome,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              "Your cart is empty",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Tap to browse products",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onGoToHome,
              icon: Icon(Icons.home),
              label: Text("Go to Home"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Your Cart",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Review your selected items before checkout.",
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
