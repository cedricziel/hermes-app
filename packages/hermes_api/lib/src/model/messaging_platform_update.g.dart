// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'messaging_platform_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MessagingPlatformUpdateCWProxy {
  MessagingPlatformUpdate enabled(bool? enabled);

  MessagingPlatformUpdate env(Map<String, String>? env);

  MessagingPlatformUpdate clearEnv(List<String>? clearEnv);

  MessagingPlatformUpdate profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MessagingPlatformUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MessagingPlatformUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  MessagingPlatformUpdate call({
    bool? enabled,
    Map<String, String>? env,
    List<String>? clearEnv,
    String? profile,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMessagingPlatformUpdate.copyWith(...)` or call `instanceOfMessagingPlatformUpdate.copyWith.fieldName(value)` for a single field.
class _$MessagingPlatformUpdateCWProxyImpl
    implements _$MessagingPlatformUpdateCWProxy {
  const _$MessagingPlatformUpdateCWProxyImpl(this._value);

  final MessagingPlatformUpdate _value;

  @override
  MessagingPlatformUpdate enabled(bool? enabled) => call(enabled: enabled);

  @override
  MessagingPlatformUpdate env(Map<String, String>? env) => call(env: env);

  @override
  MessagingPlatformUpdate clearEnv(List<String>? clearEnv) =>
      call(clearEnv: clearEnv);

  @override
  MessagingPlatformUpdate profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MessagingPlatformUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MessagingPlatformUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MessagingPlatformUpdate call({
    Object? enabled = const $CopyWithPlaceholder(),
    Object? env = const $CopyWithPlaceholder(),
    Object? clearEnv = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return MessagingPlatformUpdate(
      enabled: enabled == const $CopyWithPlaceholder()
          ? _value.enabled
          // ignore: cast_nullable_to_non_nullable
          : enabled as bool?,
      env: env == const $CopyWithPlaceholder()
          ? _value.env
          // ignore: cast_nullable_to_non_nullable
          : env as Map<String, String>?,
      clearEnv: clearEnv == const $CopyWithPlaceholder()
          ? _value.clearEnv
          // ignore: cast_nullable_to_non_nullable
          : clearEnv as List<String>?,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $MessagingPlatformUpdateCopyWith on MessagingPlatformUpdate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMessagingPlatformUpdate.copyWith(...)` or `instanceOfMessagingPlatformUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MessagingPlatformUpdateCWProxy get copyWith =>
      _$MessagingPlatformUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MessagingPlatformUpdate _$MessagingPlatformUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MessagingPlatformUpdate', json, ($checkedConvert) {
  final val = MessagingPlatformUpdate(
    enabled: $checkedConvert('enabled', (v) => v as bool?),
    env: $checkedConvert(
      'env',
      (v) =>
          (v as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          {},
    ),
    clearEnv: $checkedConvert(
      'clear_env',
      (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
    ),
    profile: $checkedConvert('profile', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'clearEnv': 'clear_env'});

Map<String, dynamic> _$MessagingPlatformUpdateToJson(
  MessagingPlatformUpdate instance,
) => <String, dynamic>{
  'enabled': ?instance.enabled,
  'env': ?instance.env,
  'clear_env': ?instance.clearEnv,
  'profile': ?instance.profile,
};
