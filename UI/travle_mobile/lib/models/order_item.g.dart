// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => OrderItem(
  id: (json['id'] as num).toInt(),
  productId: (json['productId'] as num).toInt(),
  productName: json['productName'] as String,
  quantity: (json['quantity'] as num).toInt(),
  unitPrice: (json['unitPrice'] as num).toDouble(),
);

Map<String, dynamic> _$OrderItemToJson(OrderItem instance) => <String, dynamic>{
  'id': instance.id,
  'productId': instance.productId,
  'productName': instance.productName,
  'quantity': instance.quantity,
  'unitPrice': instance.unitPrice,
};
