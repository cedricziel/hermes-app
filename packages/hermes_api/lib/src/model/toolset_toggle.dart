//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'toolset_toggle.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ToolsetToggle {
  /// Returns a new [ToolsetToggle] instance.
  ToolsetToggle({required this.enabled, this.profile});

  @JsonKey(name: r'enabled', required: true, includeIfNull: false)
  final bool enabled;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolsetToggle &&
          other.enabled == enabled &&
          other.profile == profile;

  @override
  int get hashCode =>
      enabled.hashCode + (profile == null ? 0 : profile.hashCode);

  factory ToolsetToggle.fromJson(Map<String, dynamic> json) =>
      _$ToolsetToggleFromJson(json);

  Map<String, dynamic> toJson() => _$ToolsetToggleToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
