//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'tts_lease_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TTSLeaseRequest {
  /// Returns a new [TTSLeaseRequest] instance.
  TTSLeaseRequest({required this.lease, this.active = true});

  @JsonKey(name: r'lease', required: true, includeIfNull: false)
  final String lease;

  @JsonKey(
    defaultValue: true,
    name: r'active',
    required: false,
    includeIfNull: false,
  )
  final bool? active;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TTSLeaseRequest &&
          other.lease == lease &&
          other.active == active;

  @override
  int get hashCode => lease.hashCode + active.hashCode;

  factory TTSLeaseRequest.fromJson(Map<String, dynamic> json) =>
      _$TTSLeaseRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TTSLeaseRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
