import 'package:json_annotation/json_annotation.dart';

import 'revenue_group_row.dart';

part 'revenue_report.g.dart';

/// The revenue-by-category/region report (mirrors the backend `RevenueReport`): two
/// single-GroupBy breakdowns of the same captured payments plus the reconciling
/// grand totals. Revenue is attributed to each tour's primary destination.
@JsonSerializable()
class RevenueReport {
  RevenueReport({
    required this.byCategory,
    required this.byRegion,
    required this.totalGross,
    required this.totalRefunded,
    required this.totalNet,
    required this.currency,
    this.fromDate,
    this.toDate,
  });

  final List<RevenueGroupRow> byCategory;
  final List<RevenueGroupRow> byRegion;
  final double totalGross;
  final double totalRefunded;
  final double totalNet;
  final String currency;
  final DateTime? fromDate;
  final DateTime? toDate;

  factory RevenueReport.fromJson(Map<String, dynamic> json) =>
      _$RevenueReportFromJson(json);

  Map<String, dynamic> toJson() => _$RevenueReportToJson(this);
}
