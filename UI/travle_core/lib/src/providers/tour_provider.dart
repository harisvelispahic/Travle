import '../models/tour_insert_request.dart';
import '../models/tour_response.dart';
import '../models/tour_schedule_insert_request.dart';
import '../models/tour_schedule_response.dart';
import '../models/tour_update_request.dart';
import '../network/base_provider.dart';
import '../network/search_result.dart';

/// Tours (`/Tours`). The plain paginated `get` is the public, active-only browse
/// (filterable by `text`/`tourTypeId`/`destinationId`/`onlyWithUpcomingSchedules`);
/// [mine] is the current organizer's own tours (any state). Creating/editing/
/// (de)activating/deleting and the schedule verbs are organizer-only + ownership,
/// enforced server-side.
class TourProvider extends BaseProvider<TourResponse> {
  TourProvider() : super('Tours');

  @override
  TourResponse fromJson(Map<String, dynamic> json) =>
      TourResponse.fromJson(json);

  /// The current organizer's own tours (`GET /Tours/mine`), active or not.
  Future<SearchResult<TourResponse>> mine({dynamic filter}) async {
    final json = await getAction('mine', filter: filter) as Map<String, dynamic>;
    return _pageOf(json);
  }

  /// A tour's detail (`GET /Tours/{id}`) — ordered stops + upcoming schedules.
  Future<TourResponse> getDetail(int id) => getById(id);

  /// Creates a tour (`POST /Tours`). Returns the created row. Organizer only.
  Future<TourResponse> create(TourInsertRequest request) =>
      insert(request.toJson());

  /// Edits a tour (`PUT /Tours/{id}`). Owner organizer (or admin) only.
  Future<TourResponse> edit(int id, TourUpdateRequest request) =>
      update(id, request.toJson());

  /// Hard-deletes a tour (`DELETE /Tours/{id}`) — allowed only when it was never
  /// scheduled; otherwise the server returns a friendly conflict (deactivate instead).
  Future<void> delete(int id) => remove(id);

  /// Deactivates a tour (`POST /Tours/{id}/Deactivate`): hides it from browsing
  /// and new bookings while keeping its history. Returns the updated row.
  Future<TourResponse> deactivate(int id) async {
    final json = await postAction('$id/Deactivate');
    return fromJson(json as Map<String, dynamic>);
  }

  /// Reactivates a deactivated tour (`POST /Tours/{id}/Activate`).
  Future<TourResponse> activate(int id) async {
    final json = await postAction('$id/Activate');
    return fromJson(json as Map<String, dynamic>);
  }

  /// A tour's schedule slots (`GET /Tours/{tourId}/Schedules`), paginated. As the
  /// owner/admin the [filter] (`activeOnly`/`fromDate`/`toDate`/`hasFreeSeats`) is
  /// honoured; other callers only ever see Active, future slots.
  Future<SearchResult<TourScheduleResponse>> schedules(int tourId, {dynamic filter}) async {
    final json =
        await getAction('$tourId/Schedules', filter: filter) as Map<String, dynamic>;
    return SearchResult<TourScheduleResponse>()
      ..totalCount = json['totalCount'] as int?
      ..items = (json['items'] as List)
          .map((e) => TourScheduleResponse.fromJson(e as Map<String, dynamic>))
          .toList();
  }

  /// Adds a schedule slot (`POST /Tours/{tourId}/Schedules`). Owner organizer only.
  Future<TourScheduleResponse> addSchedule(
      int tourId, TourScheduleInsertRequest request) async {
    final json = await postAction('$tourId/Schedules', request.toJson());
    return TourScheduleResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Cancels a schedule slot with a mandatory reason
  /// (`POST /Tours/Schedules/{scheduleId}/Cancel`). Owner organizer only.
  Future<TourScheduleResponse> cancelSchedule(int scheduleId, String reason) async {
    final json = await postAction('Schedules/$scheduleId/Cancel', {'reason': reason});
    return TourScheduleResponse.fromJson(json as Map<String, dynamic>);
  }

  /// Hard-deletes a future, un-booked schedule (`DELETE /Tours/Schedules/{scheduleId}`).
  Future<void> deleteSchedule(int scheduleId) =>
      deleteAction('Schedules/$scheduleId');

  SearchResult<TourResponse> _pageOf(Map<String, dynamic> json) =>
      SearchResult<TourResponse>()
        ..totalCount = json['totalCount'] as int?
        ..items = (json['items'] as List)
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList();
}
