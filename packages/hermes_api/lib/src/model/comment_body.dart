//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'comment_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CommentBody {
  /// Returns a new [CommentBody] instance.
  CommentBody({required this.body, this.author});

  @JsonKey(name: r'body', required: true, includeIfNull: false)
  final String body;

  @JsonKey(name: r'author', required: false, includeIfNull: false)
  final String? author;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommentBody && other.body == body && other.author == author;

  @override
  int get hashCode => body.hashCode + (author == null ? 0 : author.hashCode);

  factory CommentBody.fromJson(Map<String, dynamic> json) =>
      _$CommentBodyFromJson(json);

  Map<String, dynamic> toJson() => _$CommentBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
