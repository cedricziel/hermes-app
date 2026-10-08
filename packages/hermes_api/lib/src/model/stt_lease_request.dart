//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'stt_lease_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class STTLeaseRequest {
  /// Returns a new [STTLeaseRequest] instance.
  STTLeaseRequest({required this.lease, this.active = true});

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
      other is STTLeaseRequest &&
          other.lease == lease &&
          other.active == active;

  @override
  int get hashCode => lease.hashCode + active.hashCode;

  factory STTLeaseRequest.fromJson(Map<String, dynamic> json) =>
      _$STTLeaseRequestFromJson(json);

  Map<String, dynamic> toJson() => _$STTLeaseRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
