import 'package:json_annotation/json_annotation.dart';

part 'user_onboarding_request.g.dart';

/// Post-registration interest picks (mirrors the backend `UserOnboardingRequest`).
/// Both lists come from the DB; empty lists are a valid "skip". Written once as
/// OnboardingInterest interactions to seed the recommender's cold start.
@JsonSerializable()
class UserOnboardingRequest {
  UserOnboardingRequest({
    this.categoryIds = const [],
    this.tagIds = const [],
  });

  final List<int> categoryIds;
  final List<int> tagIds;

  factory UserOnboardingRequest.fromJson(Map<String, dynamic> json) =>
      _$UserOnboardingRequestFromJson(json);

  Map<String, dynamic> toJson() => _$UserOnboardingRequestToJson(this);
}
