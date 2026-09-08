import '../models/refund_policy_tier_response.dart';
import '../network/base_provider.dart';

/// Reads refund-policy tiers (`GET /RefundPolicyTiers`). Reads require an
/// authenticated user; writes are admin-only (desktop reference CRUD).
class RefundPolicyTierProvider extends BaseProvider<RefundPolicyTierResponse> {
  RefundPolicyTierProvider() : super('RefundPolicyTiers');

  @override
  RefundPolicyTierResponse fromJson(Map<String, dynamic> json) =>
      RefundPolicyTierResponse.fromJson(json);

  /// Replaces the whole ladder (`PUT /RefundPolicyTiers/ladder`) and returns it
  /// as saved, highest window first.
  ///
  /// The tiers are only valid as a set — they must cover every hour before
  /// departure exactly once, with refunds rising as notice grows — so a single
  /// row is not an editable unit: adding one necessarily overlaps a neighbour
  /// and removing one necessarily leaves a gap. The console therefore edits the
  /// ladder as a whole and saves it in one request.
  Future<List<RefundPolicyTierResponse>> replaceLadder(
    List<RefundPolicyTierResponse> tiers,
  ) async {
    final body = {
      'tiers': [
        for (final t in tiers)
          {
            'hoursBeforeMin': t.hoursBeforeMin,
            'hoursBeforeMax': t.hoursBeforeMax,
            'percentage': t.percentage,
          },
      ],
    };
    final decoded = await putAction('ladder', body);
    return [
      for (final row in (decoded as List? ?? const []))
        RefundPolicyTierResponse.fromJson(row as Map<String, dynamic>),
    ];
  }
}
