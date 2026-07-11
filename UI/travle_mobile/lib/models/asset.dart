
import 'package:json_annotation/json_annotation.dart';

part 'asset.g.dart';


@JsonSerializable()
class Asset {
  final int? id;
  final String? fileName;
  final String? contentType;
  final String? base64Content;
  final int? productId;
  final int? unitOfMeasureId;

Asset({
  this.id,
  this.fileName,
  this.contentType,
  this.base64Content,
  this.productId,
  this.unitOfMeasureId
});

factory Asset.fromJson(Map<String,dynamic> json) => _$AssetFromJson(json);

Map<String, dynamic> toJson() => _$AssetToJson(this);

}