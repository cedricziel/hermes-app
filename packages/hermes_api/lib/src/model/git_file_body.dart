//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'git_file_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class GitFileBody {
  /// Returns a new [GitFileBody] instance.
  GitFileBody({required this.path, this.file});

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @JsonKey(name: r'file', required: false, includeIfNull: false)
  final String? file;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GitFileBody && other.path == path && other.file == file;

  @override
  int get hashCode => path.hashCode + (file == null ? 0 : file.hashCode);

  factory GitFileBody.fromJson(Map<String, dynamic> json) =>
      _$GitFileBodyFromJson(json);

  Map<String, dynamic> toJson() => _$GitFileBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
