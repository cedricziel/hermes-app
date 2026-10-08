//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:hermes_api/src/model/custom_endpoint_model_detail.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'custom_endpoint_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CustomEndpointUpdate {
  /// Returns a new [CustomEndpointUpdate] instance.
  CustomEndpointUpdate({
    this.id = '',

    required this.name,

    required this.baseUrl,

    required this.model,

    this.apiKey,

    this.apiMode,

    this.contextLength,

    this.discoverModels = true,

    this.makeDefault = false,

    this.models,

    this.modelDetails,
  });

  @JsonKey(defaultValue: '', name: r'id', required: false, includeIfNull: false)
  final String? id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'base_url', required: true, includeIfNull: false)
  final String baseUrl;

  @JsonKey(name: r'model', required: true, includeIfNull: false)
  final String model;

  @JsonKey(name: r'api_key', required: false, includeIfNull: false)
  final String? apiKey;

  @JsonKey(name: r'api_mode', required: false, includeIfNull: false)
  final String? apiMode;

  @JsonKey(name: r'context_length', required: false, includeIfNull: false)
  final int? contextLength;

  @JsonKey(
    defaultValue: true,
    name: r'discover_models',
    required: false,
    includeIfNull: false,
  )
  final bool? discoverModels;

  @JsonKey(
    defaultValue: false,
    name: r'make_default',
    required: false,
    includeIfNull: false,
  )
  final bool? makeDefault;

  @JsonKey(name: r'models', required: false, includeIfNull: false)
  final List<String>? models;

  @JsonKey(name: r'model_details', required: false, includeIfNull: false)
  final List<CustomEndpointModelDetail>? modelDetails;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomEndpointUpdate &&
          other.id == id &&
          other.name == name &&
          other.baseUrl == baseUrl &&
          other.model == model &&
          other.apiKey == apiKey &&
          other.apiMode == apiMode &&
          other.contextLength == contextLength &&
          other.discoverModels == discoverModels &&
          other.makeDefault == makeDefault &&
          other.models == models &&
          other.modelDetails == modelDetails;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      baseUrl.hashCode +
      model.hashCode +
      (apiKey == null ? 0 : apiKey.hashCode) +
      (apiMode == null ? 0 : apiMode.hashCode) +
      (contextLength == null ? 0 : contextLength.hashCode) +
      discoverModels.hashCode +
      makeDefault.hashCode +
      (models == null ? 0 : models.hashCode) +
      (modelDetails == null ? 0 : modelDetails.hashCode);

  factory CustomEndpointUpdate.fromJson(Map<String, dynamic> json) =>
      _$CustomEndpointUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$CustomEndpointUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
