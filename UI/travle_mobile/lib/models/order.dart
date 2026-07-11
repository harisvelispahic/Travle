import 'package:json_annotation/json_annotation.dart';

import 'order_item.dart';

part 'order.g.dart';

@JsonSerializable()
class Order {
  final int id;
  final DateTime orderDate;
  final String orderNumber;
  final int status;
  final double totalAmount;
  final int userId;
  final List<OrderItem> orderItems;

  Order({
    required this.id,
    required this.orderDate,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.userId,
    this.orderItems = const [],
  });

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

  Map<String, dynamic> toJson() => _$OrderToJson(this);
}
