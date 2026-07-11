import 'package:travle_desktop/providers/base_provider.dart';

import '../models/product_review.dart';

class ProductReviewProvider extends BaseProvider<ProductReview> {
  ProductReviewProvider() : super('ProductReviews');

  @override
  ProductReview fromJson(data) =>
      ProductReview.fromJson(data as Map<String, dynamic>);
}
