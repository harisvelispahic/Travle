// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Order _$OrderFromJson(Map<String, dynamic> json) => Order(
  id: (json['id'] as num).toInt(),
  orderDate: DateTime.parse(json['orderDate'] as String),
  orderNumber: json['orderNumber'] as String,
  status: (json['status'] as num).toInt(),
  totalAmount: (json['totalAmount'] as num).toDouble(),
  userId: (json['userId'] as num).toInt(),
  orderItems:
      (json['orderItems'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$OrderToJson(Order instance) => <String, dynamic>{
  'id': instance.id,
  'orderDate': instance.orderDate.toIso8601String(),
  'orderNumber': instance.orderNumber,
  'status': instance.status,
  'totalAmount': instance.totalAmount,
  'userId': instance.userId,
  'orderItems': instance.orderItems,
};
