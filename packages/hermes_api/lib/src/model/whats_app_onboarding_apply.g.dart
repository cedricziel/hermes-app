// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whats_app_onboarding_apply.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WhatsAppOnboardingApplyCWProxy {
  WhatsAppOnboardingApply mode(String? mode);

  WhatsAppOnboardingApply allowedUsers(String? allowedUsers);

  WhatsAppOnboardingApply profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WhatsAppOnboardingApply(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WhatsAppOnboardingApply(...).copyWith(id: 12, name: "My name")
  /// ````
  WhatsAppOnboardingApply call({
    String? mode,
    String? allowedUsers,
    String? profile,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWhatsAppOnboardingApply.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWhatsAppOnboardingApply.copyWith.fieldName(...)`
class _$WhatsAppOnboardingApplyCWProxyImpl
    implements _$WhatsAppOnboardingApplyCWProxy {
  const _$WhatsAppOnboardingApplyCWProxyImpl(this._value);

  final WhatsAppOnboardingApply _value;

  @override
  WhatsAppOnboardingApply mode(String? mode) => this(mode: mode);

  @override
  WhatsAppOnboardingApply allowedUsers(String? allowedUsers) =>
      this(allowedUsers: allowedUsers);

  @override
  WhatsAppOnboardingApply profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WhatsAppOnboardingApply(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WhatsAppOnboardingApply(...).copyWith(id: 12, name: "My name")
  /// ````
  WhatsAppOnboardingApply call({
    Object? mode = const $CopyWithPlaceholder(),
    Object? allowedUsers = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return WhatsAppOnboardingApply(
      mode: mode == const $CopyWithPlaceholder()
          ? _value.mode
          // ignore: cast_nullable_to_non_nullable
          : mode as String?,
      allowedUsers: allowedUsers == const $CopyWithPlaceholder()
          ? _value.allowedUsers
          // ignore: cast_nullable_to_non_nullable
          : allowedUsers as String?,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $WhatsAppOnboardingApplyCopyWith on WhatsAppOnboardingApply {
  /// Returns a callable class that can be used as follows: `instanceOfWhatsAppOnboardingApply.copyWith(...)` or like so:`instanceOfWhatsAppOnboardingApply.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WhatsAppOnboardingApplyCWProxy get copyWith =>
      _$WhatsAppOnboardingApplyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WhatsAppOnboardingApply _$WhatsAppOnboardingApplyFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WhatsAppOnboardingApply', json, ($checkedConvert) {
  final val = WhatsAppOnboardingApply(
    mode: $checkedConvert('mode', (v) => v as String?),
    allowedUsers: $checkedConvert('allowed_users', (v) => v as String?),
    profile: $checkedConvert('profile', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'allowedUsers': 'allowed_users'});

Map<String, dynamic> _$WhatsAppOnboardingApplyToJson(
  WhatsAppOnboardingApply instance,
) => <String, dynamic>{
  'mode': ?instance.mode,
  'allowed_users': ?instance.allowedUsers,
  'profile': ?instance.profile,
};
