import 'package:travle_mobile/models/product.dart';

class Cart {
  List<CartItem> items = [];
}

class CartItem {
  late Product product;
  late int quantity;
}
