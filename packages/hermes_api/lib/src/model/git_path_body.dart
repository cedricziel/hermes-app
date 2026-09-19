//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'git_path_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GitPathBody {
  /// Returns a new [GitPathBody] instance.
  GitPathBody({required this.path});

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is GitPathBody && other.path == path;

  @override
  int get hashCode => path.hashCode;

  factory GitPathBody.fromJson(Map<String, dynamic> json) =>
      _$GitPathBodyFromJson(json);

  Map<String, dynamic> toJson() => _$GitPathBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
