import 'dart:typed_data';

import '../models/dashboard_response.dart';
import '../models/organizer_stats_response.dart';
import '../models/popular_destinations_report.dart';
import '../models/revenue_report.dart';
import '../network/base_provider.dart';

/// Reporting module (`/Reports`): the admin dashboard, the two report previews and
/// their PDF downloads, and the organizer statistics screen. All read-only; the base
/// type is [DashboardResponse] but every route parses its own shape (or raw bytes for
/// the PDFs). Reuses the base auth header + 401→refresh pass.
class ReportProvider extends BaseProvider<DashboardResponse> {
  ReportProvider() : super('Reports');

  @override
  DashboardResponse fromJson(Map<String, dynamic> json) =>
      DashboardResponse.fromJson(json);

  /// Admin dashboard metrics, chart series and recent activity (`GET /Reports/dashboard`).
  Future<DashboardResponse> getDashboard() async {
    final json = await getAction('dashboard') as Map<String, dynamic>;
    return DashboardResponse.fromJson(json);
  }

  /// "Most popular destinations by period" preview data (`GET /Reports/popular-destinations`).
  Future<PopularDestinationsReport> getPopularDestinations({dynamic filter}) async {
    final json =
        await getAction('popular-destinations', filter: filter) as Map<String, dynamic>;
    return PopularDestinationsReport.fromJson(json);
  }

  /// "Revenue by category / region" preview data (`GET /Reports/revenue`).
  Future<RevenueReport> getRevenue({dynamic filter}) async {
    final json = await getAction('revenue', filter: filter) as Map<String, dynamic>;
    return RevenueReport.fromJson(json);
  }

  /// The organizer's own-tours statistics (`GET /Reports/organizer-stats`).
  Future<OrganizerStatsResponse> getOrganizerStats() async {
    final json = await getAction('organizer-stats') as Map<String, dynamic>;
    return OrganizerStatsResponse.fromJson(json);
  }

  /// The popular-destinations report PDF bytes (`GET /Reports/popular-destinations/pdf`).
  Future<Uint8List> popularDestinationsPdf({dynamic filter}) =>
      getBytes(_withQuery('popular-destinations/pdf', filter));

  /// The revenue report PDF bytes (`GET /Reports/revenue/pdf`).
  Future<Uint8List> revenuePdf({dynamic filter}) =>
      getBytes(_withQuery('revenue/pdf', filter));

  // Appends the filter as a query string to a sub-path (getBytes takes no filter).
  String _withQuery(String subPath, dynamic filter) {
    if (filter == null) return subPath;
    final map =
        filter is Map<String, dynamic> ? filter : (filter as dynamic).toJson() as Map<String, dynamic>;
    final qs = getQueryString(map); // returns "&k=v&k2=v2"
    return qs.isEmpty ? subPath : '$subPath?${qs.substring(1)}';
  }
}
