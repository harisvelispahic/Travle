import 'package:json_annotation/json_annotation.dart';

part 'refund_policy_tier_response.g.dart';

/// A global refund-policy tier (mirrors the backend `RefundPolicyTierResponse`).
/// Maps a cancellation window — [hoursBeforeMin] up to (exclusive) an optional
/// [hoursBeforeMax] hours before the slot — to a refund [percentage] (0–100).
/// A null [hoursBeforeMax] is the open-ended top tier (e.g. more than 72h out).
@JsonSerializable()
class RefundPolicyTierResponse {
  RefundPolicyTierResponse({
    required this.id,
    required this.hoursBeforeMin,
    required this.percentage,
    required this.createdAt,
    this.hoursBeforeMax,
    this.modifiedAt,
  });

  final int id;
  final int hoursBeforeMin;
  final int? hoursBeforeMax;
  final int percentage;
  final DateTime createdAt;
  final DateTime? modifiedAt;

  factory RefundPolicyTierResponse.fromJson(Map<String, dynamic> json) =>
      _$RefundPolicyTierResponseFromJson(json);

  Map<String, dynamic> toJson() => _$RefundPolicyTierResponseToJson(this);
}
