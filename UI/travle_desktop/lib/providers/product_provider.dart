import 'package:travle_desktop/providers/base_provider.dart';

import '../models/product.dart';

class ProductProvider extends BaseProvider<Product> {
  ProductProvider() : super("Products");

  @override
  Product fromJson(data) {
    return Product.fromJson(data);
  }
}
