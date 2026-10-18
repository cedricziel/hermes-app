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

  EnvVarUpdate providerSetup(bool? providerSetup);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `EnvVarUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// EnvVarUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  EnvVarUpdate call({
    String key,
    String value,
    String? profile,
    String? apiKey,
    bool? providerSetup,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfEnvVarUpdate.copyWith(...)` or call `instanceOfEnvVarUpdate.copyWith.fieldName(value)` for a single field.
class _$EnvVarUpdateCWProxyImpl implements _$EnvVarUpdateCWProxy {
  const _$EnvVarUpdateCWProxyImpl(this._value);

  final EnvVarUpdate _value;

  @override
  EnvVarUpdate key(String key) => call(key: key);

  @override
  EnvVarUpdate value(String value) => call(value: value);

  @override
  EnvVarUpdate profile(String? profile) => call(profile: profile);

  @override
  EnvVarUpdate apiKey(String? apiKey) => call(apiKey: apiKey);

  @override
  EnvVarUpdate providerSetup(bool? providerSetup) =>
      call(providerSetup: providerSetup);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `EnvVarUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// EnvVarUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  EnvVarUpdate call({
    Object? key = const $CopyWithPlaceholder(),
    Object? value = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
    Object? apiKey = const $CopyWithPlaceholder(),
    Object? providerSetup = const $CopyWithPlaceholder(),
  }) {
    return EnvVarUpdate(
      key: key == const $CopyWithPlaceholder() || key == null
          ? _value.key
          // ignore: cast_nullable_to_non_nullable
          : key as String,
      value: value == const $CopyWithPlaceholder() || value == null
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
      providerSetup: providerSetup == const $CopyWithPlaceholder()
          ? _value.providerSetup
          // ignore: cast_nullable_to_non_nullable
          : providerSetup as bool?,
    );
  }
}

extension $EnvVarUpdateCopyWith on EnvVarUpdate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfEnvVarUpdate.copyWith(...)` or `instanceOfEnvVarUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EnvVarUpdateCWProxy get copyWith => _$EnvVarUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EnvVarUpdate _$EnvVarUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('EnvVarUpdate', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['key', 'value']);
  final val = EnvVarUpdate(
    key: $checkedConvert('key', (v) => v as String),
    value: $checkedConvert('value', (v) => v as String),
    profile: $checkedConvert('profile', (v) => v as String?),
    apiKey: $checkedConvert('api_key', (v) => v as String? ?? ''),
    providerSetup: $checkedConvert(
      'provider_setup',
      (v) => v as bool? ?? false,
    ),
  );
  return val;
}, fieldKeyMap: const {'apiKey': 'api_key', 'providerSetup': 'provider_setup'});

Map<String, dynamic> _$EnvVarUpdateToJson(EnvVarUpdate instance) =>
    <String, dynamic>{
      'key': instance.key,
      'value': instance.value,
      'profile': ?instance.profile,
      'api_key': ?instance.apiKey,
      'provider_setup': ?instance.providerSetup,
    };
