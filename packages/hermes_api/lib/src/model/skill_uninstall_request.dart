//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'skill_uninstall_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SkillUninstallRequest {
  /// Returns a new [SkillUninstallRequest] instance.
  SkillUninstallRequest({required this.name, this.profile});

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillUninstallRequest &&
          other.name == name &&
          other.profile == profile;

  @override
  int get hashCode => name.hashCode + (profile == null ? 0 : profile.hashCode);

  factory SkillUninstallRequest.fromJson(Map<String, dynamic> json) =>
      _$SkillUninstallRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SkillUninstallRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
