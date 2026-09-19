//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'whats_app_onboarding_start.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WhatsAppOnboardingStart {
  /// Returns a new [WhatsAppOnboardingStart] instance.
  WhatsAppOnboardingStart({this.mode, this.allowedUsers, this.profile});

  @JsonKey(name: r'mode', required: false, includeIfNull: false)
  final String? mode;

  @JsonKey(name: r'allowed_users', required: false, includeIfNull: false)
  final String? allowedUsers;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WhatsAppOnboardingStart &&
          other.mode == mode &&
          other.allowedUsers == allowedUsers &&
          other.profile == profile;

  @override
  int get hashCode =>
      (mode == null ? 0 : mode.hashCode) +
      (allowedUsers == null ? 0 : allowedUsers.hashCode) +
      (profile == null ? 0 : profile.hashCode);

  factory WhatsAppOnboardingStart.fromJson(Map<String, dynamic> json) =>
      _$WhatsAppOnboardingStartFromJson(json);

  Map<String, dynamic> toJson() => _$WhatsAppOnboardingStartToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
