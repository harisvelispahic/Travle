// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refund_policy_tier_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RefundPolicyTierResponse _$RefundPolicyTierResponseFromJson(
  Map<String, dynamic> json,
) => RefundPolicyTierResponse(
  id: (json['id'] as num).toInt(),
  hoursBeforeMin: (json['hoursBeforeMin'] as num).toInt(),
  percentage: (json['percentage'] as num).toInt(),
  createdAt: DateTime.parse(json['createdAt'] as String),
  hoursBeforeMax: (json['hoursBeforeMax'] as num?)?.toInt(),
  modifiedAt: json['modifiedAt'] == null
      ? null
      : DateTime.parse(json['modifiedAt'] as String),
);

Map<String, dynamic> _$RefundPolicyTierResponseToJson(
  RefundPolicyTierResponse instance,
) => <String, dynamic>{
  'id': instance.id,
  'hoursBeforeMin': instance.hoursBeforeMin,
  'hoursBeforeMax': instance.hoursBeforeMax,
  'percentage': instance.percentage,
  'createdAt': instance.createdAt.toIso8601String(),
  'modifiedAt': instance.modifiedAt?.toIso8601String(),
};
