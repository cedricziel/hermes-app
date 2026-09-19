//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'toolset_env_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ToolsetEnvUpdate {
  /// Returns a new [ToolsetEnvUpdate] instance.
  ToolsetEnvUpdate({required this.env, this.profile});

  @JsonKey(name: r'env', required: true, includeIfNull: false)
  final Map<String, String> env;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolsetEnvUpdate && other.env == env && other.profile == profile;

  @override
  int get hashCode => env.hashCode + (profile == null ? 0 : profile.hashCode);

  factory ToolsetEnvUpdate.fromJson(Map<String, dynamic> json) =>
      _$ToolsetEnvUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$ToolsetEnvUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
