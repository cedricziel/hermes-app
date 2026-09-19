// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telegram_onboarding_apply.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TelegramOnboardingApplyCWProxy {
  TelegramOnboardingApply allowedUserIds(List<String> allowedUserIds);

  TelegramOnboardingApply profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TelegramOnboardingApply(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TelegramOnboardingApply(...).copyWith(id: 12, name: "My name")
  /// ````
  TelegramOnboardingApply call({List<String> allowedUserIds, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTelegramOnboardingApply.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTelegramOnboardingApply.copyWith.fieldName(...)`
class _$TelegramOnboardingApplyCWProxyImpl
    implements _$TelegramOnboardingApplyCWProxy {
  const _$TelegramOnboardingApplyCWProxyImpl(this._value);

  final TelegramOnboardingApply _value;

  @override
  TelegramOnboardingApply allowedUserIds(List<String> allowedUserIds) =>
      this(allowedUserIds: allowedUserIds);

  @override
  TelegramOnboardingApply profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TelegramOnboardingApply(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TelegramOnboardingApply(...).copyWith(id: 12, name: "My name")
  /// ````
  TelegramOnboardingApply call({
    Object? allowedUserIds = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return TelegramOnboardingApply(
      allowedUserIds: allowedUserIds == const $CopyWithPlaceholder()
          ? _value.allowedUserIds
          // ignore: cast_nullable_to_non_nullable
          : allowedUserIds as List<String>,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $TelegramOnboardingApplyCopyWith on TelegramOnboardingApply {
  /// Returns a callable class that can be used as follows: `instanceOfTelegramOnboardingApply.copyWith(...)` or like so:`instanceOfTelegramOnboardingApply.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TelegramOnboardingApplyCWProxy get copyWith =>
      _$TelegramOnboardingApplyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TelegramOnboardingApply _$TelegramOnboardingApplyFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('TelegramOnboardingApply', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['allowed_user_ids']);
  final val = TelegramOnboardingApply(
    allowedUserIds: $checkedConvert(
      'allowed_user_ids',
      (v) => (v as List<dynamic>).map((e) => e as String).toList(),
    ),
    profile: $checkedConvert('profile', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'allowedUserIds': 'allowed_user_ids'});

Map<String, dynamic> _$TelegramOnboardingApplyToJson(
  TelegramOnboardingApply instance,
) => <String, dynamic>{
  'allowed_user_ids': instance.allowedUserIds,
  'profile': ?instance.profile,
};
