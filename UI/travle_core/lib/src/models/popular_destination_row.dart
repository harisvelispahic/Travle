import 'package:json_annotation/json_annotation.dart';

part 'popular_destination_row.g.dart';

/// One ranked row of the popular-destinations report (mirrors the backend
/// `PopularDestinationRow`). [bookings] is the popularity metric (bookings in the
/// period on tours visiting this destination); [views]/[favorites] are all-time
/// engagement columns for context.
@JsonSerializable()
class PopularDestinationRow {
  PopularDestinationRow({
    required this.rank,
    required this.destinationName,
    required this.categoryName,
    required this.regionName,
    required this.bookings,
    required this.travelers,
    required this.views,
    required this.favorites,
  });

  final int rank;
  final String destinationName;
  final String categoryName;
  final String regionName;
  final int bookings;
  final int travelers;
  final int views;
  final int favorites;

  factory PopularDestinationRow.fromJson(Map<String, dynamic> json) =>
      _$PopularDestinationRowFromJson(json);

  Map<String, dynamic> toJson() => _$PopularDestinationRowToJson(this);
}
