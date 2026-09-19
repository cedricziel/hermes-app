//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'skills_update_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SkillsUpdateRequest {
  /// Returns a new [SkillsUpdateRequest] instance.
  SkillsUpdateRequest({this.profile});

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillsUpdateRequest && other.profile == profile;

  @override
  int get hashCode => (profile == null ? 0 : profile.hashCode);

  factory SkillsUpdateRequest.fromJson(Map<String, dynamic> json) =>
      _$SkillsUpdateRequestFromJson(json);

  Map<String, dynamic> toJson() => _$SkillsUpdateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
