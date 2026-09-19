//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'toolset_model_select.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ToolsetModelSelect {
  /// Returns a new [ToolsetModelSelect] instance.
  ToolsetModelSelect({required this.model, this.provider, this.profile});

  @JsonKey(name: r'model', required: true, includeIfNull: false)
  final String model;

  @JsonKey(name: r'provider', required: false, includeIfNull: false)
  final String? provider;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolsetModelSelect &&
          other.model == model &&
          other.provider == provider &&
          other.profile == profile;

  @override
  int get hashCode =>
      model.hashCode +
      (provider == null ? 0 : provider.hashCode) +
      (profile == null ? 0 : profile.hashCode);

  factory ToolsetModelSelect.fromJson(Map<String, dynamic> json) =>
      _$ToolsetModelSelectFromJson(json);

  Map<String, dynamic> toJson() => _$ToolsetModelSelectToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
