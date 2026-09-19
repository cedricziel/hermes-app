//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'skill_create.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SkillCreate {
  /// Returns a new [SkillCreate] instance.
  SkillCreate({
    required this.name,

    required this.content,

    this.category,

    this.profile,
  });

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'content', required: true, includeIfNull: false)
  final String content;

  @JsonKey(name: r'category', required: false, includeIfNull: false)
  final String? category;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillCreate &&
          other.name == name &&
          other.content == content &&
          other.category == category &&
          other.profile == profile;

  @override
  int get hashCode =>
      name.hashCode +
      content.hashCode +
      (category == null ? 0 : category.hashCode) +
      (profile == null ? 0 : profile.hashCode);

  factory SkillCreate.fromJson(Map<String, dynamic> json) =>
      _$SkillCreateFromJson(json);

  Map<String, dynamic> toJson() => _$SkillCreateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
