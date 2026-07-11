
import 'package:json_annotation/json_annotation.dart';

part 'product_type.g.dart';


@JsonSerializable()
class ProductType {
  final int? id;
  final String? name;
  final String? description;

ProductType({
  this.id,
  this.name,
  this.description
});

factory ProductType.fromJson(Map<String,dynamic> json) => _$ProductTypeFromJson(json);

Map<String, dynamic> toJson() => _$ProductTypeToJson(this);

}