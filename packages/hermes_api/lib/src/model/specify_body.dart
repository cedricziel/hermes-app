//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'specify_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SpecifyBody {
  /// Returns a new [SpecifyBody] instance.
  SpecifyBody({this.author});

  @JsonKey(name: r'author', required: false, includeIfNull: false)
  final String? author;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SpecifyBody && other.author == author;

  @override
  int get hashCode => (author == null ? 0 : author.hashCode);

  factory SpecifyBody.fromJson(Map<String, dynamic> json) =>
      _$SpecifyBodyFromJson(json);

  Map<String, dynamic> toJson() => _$SpecifyBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
