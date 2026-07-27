import '../models/booking_insert_request.dart';
import '../models/booking_response.dart';
import '../network/base_provider.dart';
import '../network/search_result.dart';

/// Bookings (`/Bookings`). Not a CRUD resource: creation and every transition run
/// through the backend booking state machine. [mine] is the current traveler's own
/// history, [forMyTours] is an organizer's bookings, and the plain paginated `get`
/// is the admin-only all-bookings view. All scoping/ownership is enforced server-side.
class BookingProvider extends BaseProvider<BookingResponse> {
  BookingProvider() : super('Bookings');

  @override
  BookingResponse fromJson(Map<String, dynamic> json) =>
      BookingResponse.fromJson(json);

  /// The current traveler's own bookings (`GET /Bookings/mine`), newest first.
  Future<SearchResult<BookingResponse>> mine({dynamic filter}) async {
    final json = await getAction('mine', filter: filter) as Map<String, dynamic>;
    return _pageOf(json);
  }

  /// Bookings on the current organizer's tours (`GET /Bookings/my-tours`).
  Future<SearchResult<BookingResponse>> forMyTours({dynamic filter}) async {
    final json =
        await getAction('my-tours', filter: filter) as Map<String, dynamic>;
    return _pageOf(json);
  }

  /// A booking's detail (`GET /Bookings/{id}`) — owner, the tour's organizer, or admin.
  Future<BookingResponse> getDetail(int id) => getById(id);

  /// Traveler checkout (`POST /Bookings`): creates the booking as PaymentInProgress
  /// with a 15-minute hold. Returns the created row.
  Future<BookingResponse> create(BookingInsertRequest request) =>
      insert(request.toJson());

  /// Organizer confirms a pending booking (`POST /Bookings/{id}/Confirm`).
  Future<BookingResponse> confirm(int id) async {
    final json = await postAction('$id/Confirm');
    return fromJson(json as Map<String, dynamic>);
  }

  /// Organizer rejects a pending booking with a reason (`POST /Bookings/{id}/Reject`).
  Future<BookingResponse> reject(int id, String reason) async {
    final json = await postAction('$id/Reject', {'reason': reason});
    return fromJson(json as Map<String, dynamic>);
  }

  /// Traveler cancels their own booking (`POST /Bookings/{id}/Cancel`).
  Future<BookingResponse> cancel(int id, {String? reason}) async {
    final json = await postAction('$id/Cancel', {'reason': reason});
    return fromJson(json as Map<String, dynamic>);
  }

  SearchResult<BookingResponse> _pageOf(Map<String, dynamic> json) =>
      SearchResult<BookingResponse>()
        ..totalCount = json['totalCount'] as int?
        ..items = (json['items'] as List)
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList();
}
