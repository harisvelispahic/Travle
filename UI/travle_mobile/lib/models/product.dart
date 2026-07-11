import 'package:travle_mobile/models/asset.dart';
import 'package:travle_mobile/models/product_review.dart';
import 'package:json_annotation/json_annotation.dart';

part 'product.g.dart';

@JsonSerializable()
class Product {
  final int? id;
  final String? name;
  final String? description;
  final double? weight;
  final String? productState;
  final double? price;
  final int? productTypeId;
  final int? unitOfMeasureId;
  final List<Asset> assets;
  final List<ProductReview> reviews;

  Product({
    this.id,
    this.name,
    this.description,
    this.weight,
    this.productState,
    this.price,
    this.productTypeId,
    this.unitOfMeasureId,
    this.assets = const [],
    this.reviews = const [],
  });

  factory Product.fromJson(Map<String, dynamic> json) =>
      _$ProductFromJson(json);

  Map<String, dynamic> toJson() => _$ProductToJson(this);
}
