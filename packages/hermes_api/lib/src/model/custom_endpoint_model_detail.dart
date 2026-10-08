//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'custom_endpoint_model_detail.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CustomEndpointModelDetail {
  /// Returns a new [CustomEndpointModelDetail] instance.
  CustomEndpointModelDetail({
    required this.id,

    this.canonicalModel,

    this.reasoningEffort,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'canonical_model', required: false, includeIfNull: false)
  final String? canonicalModel;

  @JsonKey(name: r'reasoning_effort', required: false, includeIfNull: false)
  final String? reasoningEffort;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomEndpointModelDetail &&
          other.id == id &&
          other.canonicalModel == canonicalModel &&
          other.reasoningEffort == reasoningEffort;

  @override
  int get hashCode =>
      id.hashCode +
      (canonicalModel == null ? 0 : canonicalModel.hashCode) +
      (reasoningEffort == null ? 0 : reasoningEffort.hashCode);

  factory CustomEndpointModelDetail.fromJson(Map<String, dynamic> json) =>
      _$CustomEndpointModelDetailFromJson(json);

  Map<String, dynamic> toJson() => _$CustomEndpointModelDetailToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
