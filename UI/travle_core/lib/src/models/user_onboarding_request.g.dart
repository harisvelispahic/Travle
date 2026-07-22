// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_onboarding_request.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

UserOnboardingRequest _$UserOnboardingRequestFromJson(
  Map<String, dynamic> json,
) => UserOnboardingRequest(
  categoryIds:
      (json['categoryIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
  tagIds:
      (json['tagIds'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const [],
);

Map<String, dynamic> _$UserOnboardingRequestToJson(
  UserOnboardingRequest instance,
) => <String, dynamic>{
  'categoryIds': instance.categoryIds,
  'tagIds': instance.tagIds,
};
