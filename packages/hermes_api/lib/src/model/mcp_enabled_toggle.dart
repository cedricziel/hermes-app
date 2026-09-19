//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mcp_enabled_toggle.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MCPEnabledToggle {
  /// Returns a new [MCPEnabledToggle] instance.
  MCPEnabledToggle({required this.enabled, this.profile});

  @JsonKey(name: r'enabled', required: true, includeIfNull: false)
  final bool enabled;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MCPEnabledToggle &&
          other.enabled == enabled &&
          other.profile == profile;

  @override
  int get hashCode =>
      enabled.hashCode + (profile == null ? 0 : profile.hashCode);

  factory MCPEnabledToggle.fromJson(Map<String, dynamic> json) =>
      _$MCPEnabledToggleFromJson(json);

  Map<String, dynamic> toJson() => _$MCPEnabledToggleToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
