//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'skill_toggle.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SkillToggle {
  /// Returns a new [SkillToggle] instance.
  SkillToggle({required this.name, required this.enabled, this.profile});

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'enabled', required: true, includeIfNull: false)
  final bool enabled;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillToggle &&
          other.name == name &&
          other.enabled == enabled &&
          other.profile == profile;

  @override
  int get hashCode =>
      name.hashCode +
      enabled.hashCode +
      (profile == null ? 0 : profile.hashCode);

  factory SkillToggle.fromJson(Map<String, dynamic> json) =>
      _$SkillToggleFromJson(json);

  Map<String, dynamic> toJson() => _$SkillToggleToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
