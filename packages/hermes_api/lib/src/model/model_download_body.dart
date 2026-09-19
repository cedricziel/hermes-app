//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'model_download_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ModelDownloadBody {
  /// Returns a new [ModelDownloadBody] instance.
  ModelDownloadBody({required this.modelId});

  @JsonKey(name: r'model_id', required: true, includeIfNull: false)
  final String modelId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelDownloadBody && other.modelId == modelId;

  @override
  int get hashCode => modelId.hashCode;

  factory ModelDownloadBody.fromJson(Map<String, dynamic> json) =>
      _$ModelDownloadBodyFromJson(json);

  Map<String, dynamic> toJson() => _$ModelDownloadBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
