// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'telegram_onboarding_apply.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TelegramOnboardingApplyCWProxy {
  TelegramOnboardingApply allowedUserIds(List<String> allowedUserIds);

  TelegramOnboardingApply profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TelegramOnboardingApply(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TelegramOnboardingApply(...).copyWith(id: 12, name: "My name")
  /// ```
  TelegramOnboardingApply call({List<String> allowedUserIds, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTelegramOnboardingApply.copyWith(...)` or call `instanceOfTelegramOnboardingApply.copyWith.fieldName(value)` for a single field.
class _$TelegramOnboardingApplyCWProxyImpl
    implements _$TelegramOnboardingApplyCWProxy {
  const _$TelegramOnboardingApplyCWProxyImpl(this._value);

  final TelegramOnboardingApply _value;

  @override
  TelegramOnboardingApply allowedUserIds(List<String> allowedUserIds) =>
      call(allowedUserIds: allowedUserIds);

  @override
  TelegramOnboardingApply profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TelegramOnboardingApply(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TelegramOnboardingApply(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  TelegramOnboardingApply call({
    Object? allowedUserIds = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return TelegramOnboardingApply(
      allowedUserIds:
          allowedUserIds == const $CopyWithPlaceholder() ||
              allowedUserIds == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTelegramOnboardingApply.copyWith(...)` or `instanceOfTelegramOnboardingApply.copyWith.fieldName(...)`.
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
