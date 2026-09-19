//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'backup_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BackupRequest {
  /// Returns a new [BackupRequest] instance.
  BackupRequest({this.output});

  @JsonKey(name: r'output', required: false, includeIfNull: false)
  final String? output;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackupRequest && other.output == output;

  @override
  int get hashCode => (output == null ? 0 : output.hashCode);

  factory BackupRequest.fromJson(Map<String, dynamic> json) =>
      _$BackupRequestFromJson(json);

  Map<String, dynamic> toJson() => _$BackupRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
