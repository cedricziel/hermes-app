//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'quickstart_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class QuickstartBody {
  /// Returns a new [QuickstartBody] instance.
  QuickstartBody({this.modelId});

  @JsonKey(name: r'model_id', required: false, includeIfNull: false)
  final String? modelId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuickstartBody && other.modelId == modelId;

  @override
  int get hashCode => (modelId == null ? 0 : modelId.hashCode);

  factory QuickstartBody.fromJson(Map<String, dynamic> json) =>
      _$QuickstartBodyFromJson(json);

  Map<String, dynamic> toJson() => _$QuickstartBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
