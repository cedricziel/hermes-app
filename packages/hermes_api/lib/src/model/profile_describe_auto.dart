//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_describe_auto.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfileDescribeAuto {
  /// Returns a new [ProfileDescribeAuto] instance.
  ProfileDescribeAuto({this.overwrite = false});

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
      other is ProfileDescribeAuto && other.overwrite == overwrite;

  @override
  int get hashCode => overwrite.hashCode;

  factory ProfileDescribeAuto.fromJson(Map<String, dynamic> json) =>
      _$ProfileDescribeAutoFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileDescribeAutoToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
