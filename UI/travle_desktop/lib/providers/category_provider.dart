import 'package:travle_desktop/providers/base_provider.dart';

import '../models/category.dart';

class CategoryProvider extends BaseProvider<Category> {
  CategoryProvider() : super("Categories");

  @override
  Category fromJson(data) {
    return Category.fromJson(data);
  }
}
