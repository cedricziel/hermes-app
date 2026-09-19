//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'raw_config_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RawConfigUpdate {
  /// Returns a new [RawConfigUpdate] instance.
  RawConfigUpdate({required this.yamlText, this.profile});

  @JsonKey(name: r'yaml_text', required: true, includeIfNull: false)
  final String yamlText;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RawConfigUpdate &&
          other.yamlText == yamlText &&
          other.profile == profile;

  @override
  int get hashCode =>
      yamlText.hashCode + (profile == null ? 0 : profile.hashCode);

  factory RawConfigUpdate.fromJson(Map<String, dynamic> json) =>
      _$RawConfigUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$RawConfigUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
