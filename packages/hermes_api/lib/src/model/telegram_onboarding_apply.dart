//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'telegram_onboarding_apply.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TelegramOnboardingApply {
  /// Returns a new [TelegramOnboardingApply] instance.
  TelegramOnboardingApply({required this.allowedUserIds, this.profile});

  @JsonKey(name: r'allowed_user_ids', required: true, includeIfNull: false)
  final List<String> allowedUserIds;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TelegramOnboardingApply &&
          other.allowedUserIds == allowedUserIds &&
          other.profile == profile;

  @override
  int get hashCode =>
      allowedUserIds.hashCode + (profile == null ? 0 : profile.hashCode);

  factory TelegramOnboardingApply.fromJson(Map<String, dynamic> json) =>
      _$TelegramOnboardingApplyFromJson(json);

  Map<String, dynamic> toJson() => _$TelegramOnboardingApplyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
