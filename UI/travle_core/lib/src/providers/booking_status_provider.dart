import '../models/booking_status_response.dart';
import '../network/base_provider.dart';

/// Reads booking statuses (`GET /BookingStatuses`). Read-only reference data the
/// booking state machine depends on — the API exposes no writes.
class BookingStatusProvider extends BaseProvider<BookingStatusResponse> {
  BookingStatusProvider() : super('BookingStatuses');

  @override
  BookingStatusResponse fromJson(Map<String, dynamic> json) =>
      BookingStatusResponse.fromJson(json);
}
