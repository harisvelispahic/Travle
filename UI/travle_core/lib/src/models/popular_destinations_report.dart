import 'package:json_annotation/json_annotation.dart';

import 'popular_destination_row.dart';

part 'popular_destinations_report.g.dart';

/// The popular-destinations report (mirrors the backend `PopularDestinationsReport`):
/// the ranked rows plus the period and optional category the report was computed over.
@JsonSerializable()
class PopularDestinationsReport {
  PopularDestinationsReport({
    required this.rows,
    this.fromDate,
    this.toDate,
    this.categoryName,
  });

  final List<PopularDestinationRow> rows;
  final DateTime? fromDate;
  final DateTime? toDate;
  final String? categoryName;

  factory PopularDestinationsReport.fromJson(Map<String, dynamic> json) =>
      _$PopularDestinationsReportFromJson(json);

  Map<String, dynamic> toJson() => _$PopularDestinationsReportToJson(this);
}
