//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'fs_write_text.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FsWriteText {
  /// Returns a new [FsWriteText] instance.
  FsWriteText({required this.path, required this.content});

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @JsonKey(name: r'content', required: true, includeIfNull: false)
  final String content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FsWriteText && other.path == path && other.content == content;

  @override
  int get hashCode => path.hashCode + content.hashCode;

  factory FsWriteText.fromJson(Map<String, dynamic> json) =>
      _$FsWriteTextFromJson(json);

  Map<String, dynamic> toJson() => _$FsWriteTextToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
