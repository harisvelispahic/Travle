// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_intent_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PaymentIntentResponse _$PaymentIntentResponseFromJson(
  Map<String, dynamic> json,
) => PaymentIntentResponse(
  bookingId: (json['bookingId'] as num).toInt(),
  paymentId: (json['paymentId'] as num).toInt(),
  clientSecret: json['clientSecret'] as String,
  publishableKey: json['publishableKey'] as String,
  amount: (json['amount'] as num).toDouble(),
  currency: json['currency'] as String,
);

Map<String, dynamic> _$PaymentIntentResponseToJson(
  PaymentIntentResponse instance,
) => <String, dynamic>{
  'bookingId': instance.bookingId,
  'paymentId': instance.paymentId,
  'clientSecret': instance.clientSecret,
  'publishableKey': instance.publishableKey,
  'amount': instance.amount,
  'currency': instance.currency,
};
