// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'whats_app_onboarding_apply.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WhatsAppOnboardingApplyCWProxy {
  WhatsAppOnboardingApply mode(String? mode);

  WhatsAppOnboardingApply allowedUsers(String? allowedUsers);

  WhatsAppOnboardingApply profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `WhatsAppOnboardingApply(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// WhatsAppOnboardingApply(...).copyWith(id: 12, name: "My name")
  /// ```
  WhatsAppOnboardingApply call({
    String? mode,
    String? allowedUsers,
    String? profile,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfWhatsAppOnboardingApply.copyWith(...)` or call `instanceOfWhatsAppOnboardingApply.copyWith.fieldName(value)` for a single field.
class _$WhatsAppOnboardingApplyCWProxyImpl
    implements _$WhatsAppOnboardingApplyCWProxy {
  const _$WhatsAppOnboardingApplyCWProxyImpl(this._value);

  final WhatsAppOnboardingApply _value;

  @override
  WhatsAppOnboardingApply mode(String? mode) => call(mode: mode);

  @override
  WhatsAppOnboardingApply allowedUsers(String? allowedUsers) =>
      call(allowedUsers: allowedUsers);

  @override
  WhatsAppOnboardingApply profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `WhatsAppOnboardingApply(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// WhatsAppOnboardingApply(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfWhatsAppOnboardingApply.copyWith(...)` or `instanceOfWhatsAppOnboardingApply.copyWith.fieldName(...)`.
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
