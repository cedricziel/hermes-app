//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'decompose_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DecomposeBody {
  /// Returns a new [DecomposeBody] instance.
  DecomposeBody({this.author});

  @JsonKey(name: r'author', required: false, includeIfNull: false)
  final String? author;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DecomposeBody && other.author == author;

  @override
  int get hashCode => (author == null ? 0 : author.hashCode);

  factory DecomposeBody.fromJson(Map<String, dynamic> json) =>
      _$DecomposeBodyFromJson(json);

  Map<String, dynamic> toJson() => _$DecomposeBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
