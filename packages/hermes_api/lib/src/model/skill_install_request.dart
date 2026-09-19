//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'skill_install_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SkillInstallRequest {
  /// Returns a new [SkillInstallRequest] instance.
  SkillInstallRequest({required this.identifier, this.profile});

  @JsonKey(name: r'identifier', required: true, includeIfNull: false)
  final String identifier;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillInstallRequest &&
          other.identifier == identifier &&
          other.profile == profile;

  @override
  int get hashCode =>
      identifier.hashCode + (profile == null ? 0 : profile.hashCode);

  factory SkillInstallRequest.fromJson(Map<String, dynamic> json) =>
      _$SkillInstallRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SkillInstallRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
