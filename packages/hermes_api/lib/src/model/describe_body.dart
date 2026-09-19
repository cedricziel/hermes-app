//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'describe_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DescribeBody {
  /// Returns a new [DescribeBody] instance.
  DescribeBody({this.description});

  @JsonKey(name: r'description', required: false, includeIfNull: false)
  final String? description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DescribeBody && other.description == description;

  @override
  int get hashCode => (description == null ? 0 : description.hashCode);

  factory DescribeBody.fromJson(Map<String, dynamic> json) =>
      _$DescribeBodyFromJson(json);

  Map<String, dynamic> toJson() => _$DescribeBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
