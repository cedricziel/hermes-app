// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env_var_reveal.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EnvVarRevealCWProxy {
  EnvVarReveal key(String key);

  EnvVarReveal profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EnvVarReveal(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EnvVarReveal(...).copyWith(id: 12, name: "My name")
  /// ````
  EnvVarReveal call({String key, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEnvVarReveal.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEnvVarReveal.copyWith.fieldName(...)`
class _$EnvVarRevealCWProxyImpl implements _$EnvVarRevealCWProxy {
  const _$EnvVarRevealCWProxyImpl(this._value);

  final EnvVarReveal _value;

  @override
  EnvVarReveal key(String key) => this(key: key);

  @override
  EnvVarReveal profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EnvVarReveal(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EnvVarReveal(...).copyWith(id: 12, name: "My name")
  /// ````
  EnvVarReveal call({
    Object? key = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return EnvVarReveal(
      key: key == const $CopyWithPlaceholder()
          ? _value.key
          // ignore: cast_nullable_to_non_nullable
          : key as String,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $EnvVarRevealCopyWith on EnvVarReveal {
  /// Returns a callable class that can be used as follows: `instanceOfEnvVarReveal.copyWith(...)` or like so:`instanceOfEnvVarReveal.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EnvVarRevealCWProxy get copyWith => _$EnvVarRevealCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EnvVarReveal _$EnvVarRevealFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EnvVarReveal', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['key']);
      final val = EnvVarReveal(
        key: $checkedConvert('key', (v) => v as String),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$EnvVarRevealToJson(EnvVarReveal instance) =>
    <String, dynamic>{'key': instance.key, 'profile': ?instance.profile};
