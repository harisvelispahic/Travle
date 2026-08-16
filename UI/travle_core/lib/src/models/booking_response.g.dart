// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'booking_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BookingResponse _$BookingResponseFromJson(Map<String, dynamic> json) =>
    BookingResponse(
      id: (json['id'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      travelerName: json['travelerName'] as String,
      travelerUsername: json['travelerUsername'] as String,
      tourScheduleId: (json['tourScheduleId'] as num).toInt(),
      scheduleStartsAt: DateTime.parse(json['scheduleStartsAt'] as String),
      scheduleEndsAt: DateTime.parse(json['scheduleEndsAt'] as String),
      tourId: (json['tourId'] as num).toInt(),
      tourName: json['tourName'] as String,
      organizerId: (json['organizerId'] as num).toInt(),
      organizerName: json['organizerName'] as String,
      numberOfPeople: (json['numberOfPeople'] as num).toInt(),
      totalAmount: (json['totalAmount'] as num).toDouble(),
      entranceFeesPerPerson:
          (json['entranceFeesPerPerson'] as num?)?.toDouble() ?? 0,
      statusId: (json['statusId'] as num).toInt(),
      status: json['status'] as String,
      statusChangedAt: DateTime.parse(json['statusChangedAt'] as String),
      isPaid: json['isPaid'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
      canBeReviewed: json['canBeReviewed'] as bool? ?? false,
      reviewId: (json['reviewId'] as num?)?.toInt(),
      allowedActions:
          (json['allowedActions'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      confirmedByUserId: (json['confirmedByUserId'] as num?)?.toInt(),
      confirmedByName: json['confirmedByName'] as String?,
      rejectionReason: json['rejectionReason'] as String?,
      cancelledByUserId: (json['cancelledByUserId'] as num?)?.toInt(),
      cancelledByName: json['cancelledByName'] as String?,
      cancellationReason: json['cancellationReason'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      cancellationRefundPercentage:
          (json['cancellationRefundPercentage'] as num?)?.toInt(),
      tourThumbnail: json['tourThumbnail'] as String?,
      tourThumbnailContentType: json['tourThumbnailContentType'] as String?,
      modifiedAt: json['modifiedAt'] == null
          ? null
          : DateTime.parse(json['modifiedAt'] as String),
    );

Map<String, dynamic> _$BookingResponseToJson(BookingResponse instance) =>
    <String, dynamic>{
      'id': instance.id,
      'userId': instance.userId,
      'travelerName': instance.travelerName,
      'travelerUsername': instance.travelerUsername,
      'tourScheduleId': instance.tourScheduleId,
      'scheduleStartsAt': instance.scheduleStartsAt.toIso8601String(),
      'scheduleEndsAt': instance.scheduleEndsAt.toIso8601String(),
      'tourId': instance.tourId,
      'tourName': instance.tourName,
      'organizerId': instance.organizerId,
      'organizerName': instance.organizerName,
      'numberOfPeople': instance.numberOfPeople,
      'totalAmount': instance.totalAmount,
      'entranceFeesPerPerson': instance.entranceFeesPerPerson,
      'statusId': instance.statusId,
      'status': instance.status,
      'statusChangedAt': instance.statusChangedAt.toIso8601String(),
      'confirmedByUserId': instance.confirmedByUserId,
      'confirmedByName': instance.confirmedByName,
      'rejectionReason': instance.rejectionReason,
      'cancelledByUserId': instance.cancelledByUserId,
      'cancelledByName': instance.cancelledByName,
      'cancellationReason': instance.cancellationReason,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'isPaid': instance.isPaid,
      'canBeReviewed': instance.canBeReviewed,
      'reviewId': instance.reviewId,
      'allowedActions': instance.allowedActions,
      'cancellationRefundPercentage': instance.cancellationRefundPercentage,
      'tourThumbnail': instance.tourThumbnail,
      'tourThumbnailContentType': instance.tourThumbnailContentType,
      'createdAt': instance.createdAt.toIso8601String(),
      'modifiedAt': instance.modifiedAt?.toIso8601String(),
    };
