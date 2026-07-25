import 'package:json_annotation/json_annotation.dart';

part 'tag_ref.g.dart';

/// A lightweight tag reference (id + name) as embedded in a destination (mirrors
/// the backend `TagRef`). The id lets a form preselect the tag chips; the name is
/// what's shown.
@JsonSerializable()
class TagRef {
  TagRef({required this.id, required this.name});

  final int id;
  final String name;

  factory TagRef.fromJson(Map<String, dynamic> json) => _$TagRefFromJson(json);

  Map<String, dynamic> toJson() => _$TagRefToJson(this);
}
