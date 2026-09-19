//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'skill_content_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SkillContentUpdate {
  /// Returns a new [SkillContentUpdate] instance.
  SkillContentUpdate({required this.name, required this.content, this.profile});

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'content', required: true, includeIfNull: false)
  final String content;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillContentUpdate &&
          other.name == name &&
          other.content == content &&
          other.profile == profile;

  @override
  int get hashCode =>
      name.hashCode +
      content.hashCode +
      (profile == null ? 0 : profile.hashCode);

  factory SkillContentUpdate.fromJson(Map<String, dynamic> json) =>
      _$SkillContentUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$SkillContentUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
