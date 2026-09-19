//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'config_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ConfigUpdate {
  /// Returns a new [ConfigUpdate] instance.
  ConfigUpdate({required this.config, this.profile});

  @JsonKey(name: r'config', required: true, includeIfNull: false)
  final Map<String, Object> config;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ConfigUpdate &&
          other.config == config &&
          other.profile == profile;

  @override
  int get hashCode =>
      config.hashCode + (profile == null ? 0 : profile.hashCode);

  factory ConfigUpdate.fromJson(Map<String, dynamic> json) =>
      _$ConfigUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$ConfigUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
