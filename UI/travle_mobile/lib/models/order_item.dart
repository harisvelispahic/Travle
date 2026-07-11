import 'package:json_annotation/json_annotation.dart';

part 'order_item.g.dart';

@JsonSerializable()
class OrderItem {
  final int id;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);

  Map<String, dynamic> toJson() => _$OrderItemToJson(this);
}
