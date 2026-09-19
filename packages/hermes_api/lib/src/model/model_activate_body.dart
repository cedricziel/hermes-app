//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'model_activate_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ModelActivateBody {
  /// Returns a new [ModelActivateBody] instance.
  ModelActivateBody({required this.modelId});

  @JsonKey(name: r'model_id', required: true, includeIfNull: false)
  final String modelId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelActivateBody && other.modelId == modelId;

  @override
  int get hashCode => modelId.hashCode;

  factory ModelActivateBody.fromJson(Map<String, dynamic> json) =>
      _$ModelActivateBodyFromJson(json);

  Map<String, dynamic> toJson() => _$ModelActivateBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
