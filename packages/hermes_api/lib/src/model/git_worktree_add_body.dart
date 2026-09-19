//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'git_worktree_add_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GitWorktreeAddBody {
  /// Returns a new [GitWorktreeAddBody] instance.
  GitWorktreeAddBody({
    required this.path,

    this.name,

    this.branch,

    this.base_,

    this.existingBranch,
  });

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @JsonKey(name: r'name', required: false, includeIfNull: false)
  final String? name;

  @JsonKey(name: r'branch', required: false, includeIfNull: false)
  final String? branch;

  @JsonKey(name: r'base', required: false, includeIfNull: false)
  final String? base_;

  @JsonKey(name: r'existingBranch', required: false, includeIfNull: false)
  final String? existingBranch;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitWorktreeAddBody &&
          other.path == path &&
          other.name == name &&
          other.branch == branch &&
          other.base_ == base_ &&
          other.existingBranch == existingBranch;

  @override
  int get hashCode =>
      path.hashCode +
      (name == null ? 0 : name.hashCode) +
      (branch == null ? 0 : branch.hashCode) +
      (base_ == null ? 0 : base_.hashCode) +
      (existingBranch == null ? 0 : existingBranch.hashCode);

  factory GitWorktreeAddBody.fromJson(Map<String, dynamic> json) =>
      _$GitWorktreeAddBodyFromJson(json);

  Map<String, dynamic> toJson() => _$GitWorktreeAddBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
