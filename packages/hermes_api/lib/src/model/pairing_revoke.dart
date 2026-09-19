//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'pairing_revoke.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PairingRevoke {
  /// Returns a new [PairingRevoke] instance.
  PairingRevoke({required this.platform, required this.userId, this.profile});

  @JsonKey(name: r'platform', required: true, includeIfNull: false)
  final String platform;

  @JsonKey(name: r'user_id', required: true, includeIfNull: false)
  final String userId;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairingRevoke &&
          other.platform == platform &&
          other.userId == userId &&
          other.profile == profile;

  @override
  int get hashCode =>
      platform.hashCode +
      userId.hashCode +
      (profile == null ? 0 : profile.hashCode);

  factory PairingRevoke.fromJson(Map<String, dynamic> json) =>
      _$PairingRevokeFromJson(json);

  Map<String, dynamic> toJson() => _$PairingRevokeToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
