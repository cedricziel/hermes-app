//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'job_id_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class JobIdBody {
  /// Returns a new [JobIdBody] instance.
  JobIdBody({required this.jobId});

  @JsonKey(name: r'job_id', required: true, includeIfNull: false)
  final String jobId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is JobIdBody && other.jobId == jobId;

  @override
  int get hashCode => jobId.hashCode;

  factory JobIdBody.fromJson(Map<String, dynamic> json) =>
      _$JobIdBodyFromJson(json);

  Map<String, dynamic> toJson() => _$JobIdBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
