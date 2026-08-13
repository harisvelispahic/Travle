import 'package:json_annotation/json_annotation.dart';

part 'destination_suggestion.g.dart';

/// A single search-autocomplete row (mirrors the backend `DestinationSuggestionResponse`):
/// just the id, name, and the city/category shown as secondary context. Deliberately
/// text-only — the typeahead fires on every debounced keystroke, so no thumbnail bytes
/// travel here. Picking one fills the search box and runs the full search.
@JsonSerializable()
class DestinationSuggestion {
  DestinationSuggestion({
    required this.id,
    required this.name,
    this.cityName,
    this.categoryName,
  });

  final int id;
  final String name;

  final String? cityName;
  final String? categoryName;

  factory DestinationSuggestion.fromJson(Map<String, dynamic> json) =>
      _$DestinationSuggestionFromJson(json);

  Map<String, dynamic> toJson() => _$DestinationSuggestionToJson(this);
}
