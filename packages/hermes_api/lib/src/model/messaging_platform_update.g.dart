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

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MessagingPlatformUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MessagingPlatformUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  MessagingPlatformUpdate call({
    bool? enabled,
    Map<String, String>? env,
    List<String>? clearEnv,
    String? profile,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMessagingPlatformUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMessagingPlatformUpdate.copyWith.fieldName(...)`
class _$MessagingPlatformUpdateCWProxyImpl
    implements _$MessagingPlatformUpdateCWProxy {
  const _$MessagingPlatformUpdateCWProxyImpl(this._value);

  final MessagingPlatformUpdate _value;

  @override
  MessagingPlatformUpdate enabled(bool? enabled) => this(enabled: enabled);

  @override
  MessagingPlatformUpdate env(Map<String, String>? env) => this(env: env);

  @override
  MessagingPlatformUpdate clearEnv(List<String>? clearEnv) =>
      this(clearEnv: clearEnv);

  @override
  MessagingPlatformUpdate profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MessagingPlatformUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MessagingPlatformUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfMessagingPlatformUpdate.copyWith(...)` or like so:`instanceOfMessagingPlatformUpdate.copyWith.fieldName(...)`.
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
