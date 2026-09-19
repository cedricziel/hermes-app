//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'git_worktree_remove_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GitWorktreeRemoveBody {
  /// Returns a new [GitWorktreeRemoveBody] instance.
  GitWorktreeRemoveBody({
    required this.path,

    required this.worktreePath,

    this.force = false,
  });

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @JsonKey(name: r'worktreePath', required: true, includeIfNull: false)
  final String worktreePath;

  @JsonKey(
    defaultValue: false,
    name: r'force',
    required: false,
    includeIfNull: false,
  )
  final bool? force;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitWorktreeRemoveBody &&
          other.path == path &&
          other.worktreePath == worktreePath &&
          other.force == force;

  @override
  int get hashCode => path.hashCode + worktreePath.hashCode + force.hashCode;

  factory GitWorktreeRemoveBody.fromJson(Map<String, dynamic> json) =>
      _$GitWorktreeRemoveBodyFromJson(json);

  Map<String, dynamic> toJson() => _$GitWorktreeRemoveBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
