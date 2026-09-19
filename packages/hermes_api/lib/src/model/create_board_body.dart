//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_board_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateBoardBody {
  /// Returns a new [CreateBoardBody] instance.
  CreateBoardBody({
    required this.slug,

    this.name,

    this.description,

    this.icon,

    this.color,

    this.defaultWorkdir,

    this.projectId,

    this.switch_ = false,
  });

  @JsonKey(name: r'slug', required: true, includeIfNull: false)
  final String slug;

  @JsonKey(name: r'name', required: false, includeIfNull: false)
  final String? name;

  @JsonKey(name: r'description', required: false, includeIfNull: false)
  final String? description;

  @JsonKey(name: r'icon', required: false, includeIfNull: false)
  final String? icon;

  @JsonKey(name: r'color', required: false, includeIfNull: false)
  final String? color;

  @JsonKey(name: r'default_workdir', required: false, includeIfNull: false)
  final String? defaultWorkdir;

  @JsonKey(name: r'project_id', required: false, includeIfNull: false)
  final String? projectId;

  @JsonKey(
    defaultValue: false,
    name: r'switch',
    required: false,
    includeIfNull: false,
  )
  final bool? switch_;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateBoardBody &&
          other.slug == slug &&
          other.name == name &&
          other.description == description &&
          other.icon == icon &&
          other.color == color &&
          other.defaultWorkdir == defaultWorkdir &&
          other.projectId == projectId &&
          other.switch_ == switch_;

  @override
  int get hashCode =>
      slug.hashCode +
      (name == null ? 0 : name.hashCode) +
      (description == null ? 0 : description.hashCode) +
      (icon == null ? 0 : icon.hashCode) +
      (color == null ? 0 : color.hashCode) +
      (defaultWorkdir == null ? 0 : defaultWorkdir.hashCode) +
      (projectId == null ? 0 : projectId.hashCode) +
      switch_.hashCode;

  factory CreateBoardBody.fromJson(Map<String, dynamic> json) =>
      _$CreateBoardBodyFromJson(json);

  Map<String, dynamic> toJson() => _$CreateBoardBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
