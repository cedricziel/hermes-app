//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'git_commit_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GitCommitBody {
  /// Returns a new [GitCommitBody] instance.
  GitCommitBody({required this.path, required this.message, this.push = false});

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @JsonKey(name: r'message', required: true, includeIfNull: false)
  final String message;

  @JsonKey(
    defaultValue: false,
    name: r'push',
    required: false,
    includeIfNull: false,
  )
  final bool? push;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitCommitBody &&
          other.path == path &&
          other.message == message &&
          other.push == push;

  @override
  int get hashCode => path.hashCode + message.hashCode + push.hashCode;

  factory GitCommitBody.fromJson(Map<String, dynamic> json) =>
      _$GitCommitBodyFromJson(json);

  Map<String, dynamic> toJson() => _$GitCommitBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
