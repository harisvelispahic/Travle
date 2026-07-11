import 'package:travle_mobile/models/category.dart';
import 'package:travle_mobile/providers/base_provider.dart';

class CategoryProvider extends BaseProvider<Category> {
  CategoryProvider() : super("Categories");

  @override
  Category fromJson(data) {
    return Category.fromJson(data);
  }
}
