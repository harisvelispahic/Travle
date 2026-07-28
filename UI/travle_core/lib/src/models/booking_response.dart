import 'package:json_annotation/json_annotation.dart';

part 'booking_response.g.dart';

/// A traveler's reservation of seats on a tour schedule (mirrors the backend
/// `BookingResponse`). [status] is the booking-status name, never a raw int;
/// [allowedActions] lists the transitions the booking currently permits (enum
/// names) so the app renders exactly the buttons that will succeed — the app also
/// intersects them with what the current role can do (a traveler acts on `Cancel`
/// / `Pay`). Only the small [tourThumbnail] cover travels.
@JsonSerializable()
class BookingResponse {
  BookingResponse({
    required this.id,
    required this.userId,
    required this.travelerName,
    required this.travelerUsername,
    required this.tourScheduleId,
    required this.scheduleStartsAt,
    required this.scheduleEndsAt,
    required this.tourId,
    required this.tourName,
    required this.numberOfPeople,
    required this.totalAmount,
    this.entranceFeesPerPerson = 0,
    required this.statusId,
    required this.status,
    required this.statusChangedAt,
    required this.isPaid,
    required this.createdAt,
    this.canBeReviewed = false,
    this.reviewId,
    this.allowedActions = const [],
    this.confirmedByUserId,
    this.confirmedByName,
    this.rejectionReason,
    this.cancelledByUserId,
    this.cancelledByName,
    this.cancellationReason,
    this.expiresAt,
    this.cancellationRefundPercentage,
    this.tourThumbnail,
    this.tourThumbnailContentType,
    this.modifiedAt,
  });

  final int id;

  final int userId;
  final String travelerName;
  final String travelerUsername;

  final int tourScheduleId;
  final DateTime scheduleStartsAt;
  final DateTime scheduleEndsAt;

  final int tourId;
  final String tourName;

  final int numberOfPeople;
  final double totalAmount;

  /// Sum of the tour's destinations' entrance fees, per person (KM), paid on-site
  /// and never part of the Travle charge. 0 when no stop has a fee.
  final double entranceFeesPerPerson;

  final int statusId;

  /// PaymentInProgress / Pending / Confirmed / Completed / Cancelled / Expired.
  final String status;
  final DateTime statusChangedAt;

  final int? confirmedByUserId;
  final String? confirmedByName;
  final String? rejectionReason;

  final int? cancelledByUserId;
  final String? cancelledByName;
  final String? cancellationReason;

  /// When a PaymentInProgress hold lapses (15 min after checkout); null afterwards.
  final DateTime? expiresAt;

  final bool isPaid;

  /// True when the viewer is this booking's traveler, it is Completed, and it has
  /// no review yet — drives the "Leave a review" action.
  final bool canBeReviewed;

  /// The id of this booking's tour review if one exists, else null.
  final int? reviewId;

  /// The transitions currently allowed (enum names: `Pay`/`Confirm`/`Reject`/`Cancel`).
  final List<String> allowedActions;

  /// Refund % the traveler would get if they cancelled now (detail read, own booking).
  final int? cancellationRefundPercentage;

  /// Base64 cover thumbnail (the tour's ordered-first destination), for cards.
  final String? tourThumbnail;
  final String? tourThumbnailContentType;

  final DateTime createdAt;
  final DateTime? modifiedAt;

  bool get isPaymentInProgress => status == 'PaymentInProgress';
  bool get isPending => status == 'Pending';
  bool get isConfirmed => status == 'Confirmed';
  bool get isCompleted => status == 'Completed';
  bool get isCancelled => status == 'Cancelled';
  bool get isExpired => status == 'Expired';

  /// Whether the traveler-side actions apply in the current state.
  bool get canPay => allowedActions.contains('Pay');
  bool get canCancel => allowedActions.contains('Cancel');

  factory BookingResponse.fromJson(Map<String, dynamic> json) =>
      _$BookingResponseFromJson(json);

  Map<String, dynamic> toJson() => _$BookingResponseToJson(this);
}
