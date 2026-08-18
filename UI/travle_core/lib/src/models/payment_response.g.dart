// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentResponse _$PaymentResponseFromJson(Map<String, dynamic> json) =>
    PaymentResponse(
      id: (json['id'] as num).toInt(),
      bookingId: (json['bookingId'] as num).toInt(),
      travelerName: json['travelerName'] as String,
      travelerUsername: json['travelerUsername'] as String,
      tourName: json['tourName'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String,
      platformFeePercentage: (json['platformFeePercentage'] as num).toDouble(),
      platformFeeAmount: (json['platformFeeAmount'] as num).toDouble(),
      status: json['status'] as String,
      refundedAmount: (json['refundedAmount'] as num).toDouble(),
      refundCount: (json['refundCount'] as num).toInt(),
      refundOwed: json['refundOwed'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String),
      succeededAt: json['succeededAt'] == null
          ? null
          : DateTime.parse(json['succeededAt'] as String),
    );

Map<String, dynamic> _$PaymentResponseToJson(PaymentResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'bookingId': instance.bookingId,
      'travelerName': instance.travelerName,
      'travelerUsername': instance.travelerUsername,
      'tourName': instance.tourName,
      'amount': instance.amount,
      'currency': instance.currency,
      'platformFeePercentage': instance.platformFeePercentage,
      'platformFeeAmount': instance.platformFeeAmount,
      'status': instance.status,
      'refundedAmount': instance.refundedAmount,
      'refundCount': instance.refundCount,
      'refundOwed': instance.refundOwed,
      'succeededAt': instance.succeededAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
    };
