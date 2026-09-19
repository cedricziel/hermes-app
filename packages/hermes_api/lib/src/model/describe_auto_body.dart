//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'describe_auto_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DescribeAutoBody {
  /// Returns a new [DescribeAutoBody] instance.
  DescribeAutoBody({this.overwrite = false});

  @JsonKey(
    defaultValue: false,
    name: r'overwrite',
    required: false,
    includeIfNull: false,
  )
  final bool? overwrite;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DescribeAutoBody && other.overwrite == overwrite;

  @override
  int get hashCode => overwrite.hashCode;

  factory DescribeAutoBody.fromJson(Map<String, dynamic> json) =>
      _$DescribeAutoBodyFromJson(json);

  Map<String, dynamic> toJson() => _$DescribeAutoBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
