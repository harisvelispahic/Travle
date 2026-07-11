import 'package:collection/collection.dart';
import 'package:travle_mobile/models/cart.dart';
import 'package:flutter/material.dart';

import '../models/product.dart';

class CartProvider extends ChangeNotifier {
  Cart cart = Cart();

  addToCart(Product product) {
    print("adding to cart: ${product.name}");

    CartItem? cartItem = findCartItem(product);
    if (cartItem != null) {
      cartItem.quantity++;
    } else {
      cart.items.add(
        CartItem()
          ..product = product
          ..quantity = 1,
      );
    }

    notifyListeners();
  }

  CartItem? findCartItem(Product product) {
    return cart.items.firstWhereOrNull((item) => item.product.id == product.id);
  }

  removeFromCart(Product product) {
    CartItem? cartItem = findCartItem(product);
    if (cartItem != null) {
      cart.items.remove(cartItem);
      notifyListeners();
    }
  }

  void clearCart() {
    cart.items.clear();
    notifyListeners();
  }
}
