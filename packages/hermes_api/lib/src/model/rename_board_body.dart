//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rename_board_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RenameBoardBody {
  /// Returns a new [RenameBoardBody] instance.
  RenameBoardBody({
    this.name,

    this.description,

    this.icon,

    this.color,

    this.defaultWorkdir,

    this.projectId,
  });

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

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RenameBoardBody &&
          other.name == name &&
          other.description == description &&
          other.icon == icon &&
          other.color == color &&
          other.defaultWorkdir == defaultWorkdir &&
          other.projectId == projectId;

  @override
  int get hashCode =>
      (name == null ? 0 : name.hashCode) +
      (description == null ? 0 : description.hashCode) +
      (icon == null ? 0 : icon.hashCode) +
      (color == null ? 0 : color.hashCode) +
      (defaultWorkdir == null ? 0 : defaultWorkdir.hashCode) +
      (projectId == null ? 0 : projectId.hashCode);

  factory RenameBoardBody.fromJson(Map<String, dynamic> json) =>
      _$RenameBoardBodyFromJson(json);

  Map<String, dynamic> toJson() => _$RenameBoardBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
