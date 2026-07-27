// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_summary_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentSummaryResponse _$PaymentSummaryResponseFromJson(
  Map<String, dynamic> json,
) => PaymentSummaryResponse(
  capturedCount: (json['capturedCount'] as num).toInt(),
  grossRevenue: (json['grossRevenue'] as num).toDouble(),
  platformCommission: (json['platformCommission'] as num).toDouble(),
  organizerShare: (json['organizerShare'] as num).toDouble(),
  totalRefunded: (json['totalRefunded'] as num).toDouble(),
  refundCount: (json['refundCount'] as num).toInt(),
  netRevenue: (json['netRevenue'] as num).toDouble(),
  currency: json['currency'] as String,
);

Map<String, dynamic> _$PaymentSummaryResponseToJson(
  PaymentSummaryResponse instance,
) => <String, dynamic>{
  'capturedCount': instance.capturedCount,
  'grossRevenue': instance.grossRevenue,
  'platformCommission': instance.platformCommission,
  'organizerShare': instance.organizerShare,
  'totalRefunded': instance.totalRefunded,
  'refundCount': instance.refundCount,
  'netRevenue': instance.netRevenue,
  'currency': instance.currency,
};
