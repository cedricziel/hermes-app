//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pairing_approve.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PairingApprove {
  /// Returns a new [PairingApprove] instance.
  PairingApprove({
    required this.platform,

    this.code = '',

    this.requestId = '',

    this.profile,
  });

  @JsonKey(name: r'platform', required: true, includeIfNull: false)
  final String platform;

  @JsonKey(
    defaultValue: '',
    name: r'code',
    required: false,
    includeIfNull: false,
  )
  final String? code;

  @JsonKey(
    defaultValue: '',
    name: r'request_id',
    required: false,
    includeIfNull: false,
  )
  final String? requestId;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairingApprove &&
          other.platform == platform &&
          other.code == code &&
          other.requestId == requestId &&
          other.profile == profile;

  @override
  int get hashCode =>
      platform.hashCode +
      code.hashCode +
      requestId.hashCode +
      (profile == null ? 0 : profile.hashCode);

  factory PairingApprove.fromJson(Map<String, dynamic> json) =>
      _$PairingApproveFromJson(json);

  Map<String, dynamic> toJson() => _$PairingApproveToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
