//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'git_branch_switch_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GitBranchSwitchBody {
  /// Returns a new [GitBranchSwitchBody] instance.
  GitBranchSwitchBody({required this.path, required this.branch});

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @JsonKey(name: r'branch', required: true, includeIfNull: false)
  final String branch;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitBranchSwitchBody &&
          other.path == path &&
          other.branch == branch;

  @override
  int get hashCode => path.hashCode + branch.hashCode;

  factory GitBranchSwitchBody.fromJson(Map<String, dynamic> json) =>
      _$GitBranchSwitchBodyFromJson(json);

  Map<String, dynamic> toJson() => _$GitBranchSwitchBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
