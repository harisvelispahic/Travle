import 'package:travle_desktop/models/product_type.dart';
import 'package:travle_desktop/providers/base_provider.dart';

class ProductTypeProvider extends BaseProvider<ProductType> {
  ProductTypeProvider() : super("ProductTypes");

  @override
  ProductType fromJson(data) {
    return ProductType.fromJson(data);
  }
}
