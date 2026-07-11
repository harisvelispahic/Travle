import 'package:travle_mobile/models/product_review.dart';
import 'package:travle_mobile/providers/base_provider.dart';

class ProductReviewProvider extends BaseProvider<ProductReview> {
  ProductReviewProvider() : super('ProductReviews');

  @override
  ProductReview fromJson(data) =>
      ProductReview.fromJson(data as Map<String, dynamic>);
}
