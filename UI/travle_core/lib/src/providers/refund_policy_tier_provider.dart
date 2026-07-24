import '../models/refund_policy_tier_response.dart';
import '../network/base_provider.dart';

/// Reads refund-policy tiers (`GET /RefundPolicyTiers`). Reads require an
/// authenticated user; writes are admin-only (desktop reference CRUD).
class RefundPolicyTierProvider extends BaseProvider<RefundPolicyTierResponse> {
  RefundPolicyTierProvider() : super('RefundPolicyTiers');

  @override
  RefundPolicyTierResponse fromJson(Map<String, dynamic> json) =>
      RefundPolicyTierResponse.fromJson(json);
}
