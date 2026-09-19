// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env_var_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EnvVarUpdateCWProxy {
  EnvVarUpdate key(String key);

  EnvVarUpdate value(String value);

  EnvVarUpdate profile(String? profile);

  EnvVarUpdate apiKey(String? apiKey);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EnvVarUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EnvVarUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  EnvVarUpdate call({
    String key,
    String value,
    String? profile,
    String? apiKey,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEnvVarUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEnvVarUpdate.copyWith.fieldName(...)`
class _$EnvVarUpdateCWProxyImpl implements _$EnvVarUpdateCWProxy {
  const _$EnvVarUpdateCWProxyImpl(this._value);

  final EnvVarUpdate _value;

  @override
  EnvVarUpdate key(String key) => this(key: key);

  @override
  EnvVarUpdate value(String value) => this(value: value);

  @override
  EnvVarUpdate profile(String? profile) => this(profile: profile);

  @override
  EnvVarUpdate apiKey(String? apiKey) => this(apiKey: apiKey);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EnvVarUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EnvVarUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  EnvVarUpdate call({
    Object? key = const $CopyWithPlaceholder(),
    Object? value = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
    Object? apiKey = const $CopyWithPlaceholder(),
  }) {
    return EnvVarUpdate(
      key: key == const $CopyWithPlaceholder()
          ? _value.key
          // ignore: cast_nullable_to_non_nullable
          : key as String,
      value: value == const $CopyWithPlaceholder()
          ? _value.value
          // ignore: cast_nullable_to_non_nullable
          : value as String,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
      apiKey: apiKey == const $CopyWithPlaceholder()
          ? _value.apiKey
          // ignore: cast_nullable_to_non_nullable
          : apiKey as String?,
    );
  }
}

extension $EnvVarUpdateCopyWith on EnvVarUpdate {
  /// Returns a callable class that can be used as follows: `instanceOfEnvVarUpdate.copyWith(...)` or like so:`instanceOfEnvVarUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EnvVarUpdateCWProxy get copyWith => _$EnvVarUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EnvVarUpdate _$EnvVarUpdateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EnvVarUpdate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['key', 'value']);
      final val = EnvVarUpdate(
        key: $checkedConvert('key', (v) => v as String),
        value: $checkedConvert('value', (v) => v as String),
        profile: $checkedConvert('profile', (v) => v as String?),
        apiKey: $checkedConvert('api_key', (v) => v as String? ?? ''),
      );
      return val;
    }, fieldKeyMap: const {'apiKey': 'api_key'});

Map<String, dynamic> _$EnvVarUpdateToJson(EnvVarUpdate instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
      'profile': ?instance.profile,
      'api_key': ?instance.apiKey,
    };
