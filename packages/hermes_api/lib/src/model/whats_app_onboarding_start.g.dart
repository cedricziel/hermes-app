// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whats_app_onboarding_start.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WhatsAppOnboardingStartCWProxy {
  WhatsAppOnboardingStart mode(String? mode);

  WhatsAppOnboardingStart allowedUsers(String? allowedUsers);

  WhatsAppOnboardingStart profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WhatsAppOnboardingStart(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WhatsAppOnboardingStart(...).copyWith(id: 12, name: "My name")
  /// ````
  WhatsAppOnboardingStart call({
    String? mode,
    String? allowedUsers,
    String? profile,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWhatsAppOnboardingStart.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWhatsAppOnboardingStart.copyWith.fieldName(...)`
class _$WhatsAppOnboardingStartCWProxyImpl
    implements _$WhatsAppOnboardingStartCWProxy {
  const _$WhatsAppOnboardingStartCWProxyImpl(this._value);

  final WhatsAppOnboardingStart _value;

  @override
  WhatsAppOnboardingStart mode(String? mode) => this(mode: mode);

  @override
  WhatsAppOnboardingStart allowedUsers(String? allowedUsers) =>
      this(allowedUsers: allowedUsers);

  @override
  WhatsAppOnboardingStart profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WhatsAppOnboardingStart(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WhatsAppOnboardingStart(...).copyWith(id: 12, name: "My name")
  /// ````
  WhatsAppOnboardingStart call({
    Object? mode = const $CopyWithPlaceholder(),
    Object? allowedUsers = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return WhatsAppOnboardingStart(
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

extension $WhatsAppOnboardingStartCopyWith on WhatsAppOnboardingStart {
  /// Returns a callable class that can be used as follows: `instanceOfWhatsAppOnboardingStart.copyWith(...)` or like so:`instanceOfWhatsAppOnboardingStart.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WhatsAppOnboardingStartCWProxy get copyWith =>
      _$WhatsAppOnboardingStartCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WhatsAppOnboardingStart _$WhatsAppOnboardingStartFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('WhatsAppOnboardingStart', json, ($checkedConvert) {
  final val = WhatsAppOnboardingStart(
    mode: $checkedConvert('mode', (v) => v as String?),
    allowedUsers: $checkedConvert('allowed_users', (v) => v as String?),
    profile: $checkedConvert('profile', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'allowedUsers': 'allowed_users'});

Map<String, dynamic> _$WhatsAppOnboardingStartToJson(
  WhatsAppOnboardingStart instance,
) => <String, dynamic>{
  'mode': ?instance.mode,
  'allowed_users': ?instance.allowedUsers,
  'profile': ?instance.profile,
};
