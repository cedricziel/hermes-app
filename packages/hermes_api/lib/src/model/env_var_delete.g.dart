// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env_var_delete.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EnvVarDeleteCWProxy {
  EnvVarDelete key(String key);

  EnvVarDelete profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EnvVarDelete(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EnvVarDelete(...).copyWith(id: 12, name: "My name")
  /// ````
  EnvVarDelete call({String key, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfEnvVarDelete.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfEnvVarDelete.copyWith.fieldName(...)`
class _$EnvVarDeleteCWProxyImpl implements _$EnvVarDeleteCWProxy {
  const _$EnvVarDeleteCWProxyImpl(this._value);

  final EnvVarDelete _value;

  @override
  EnvVarDelete key(String key) => this(key: key);

  @override
  EnvVarDelete profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `EnvVarDelete(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// EnvVarDelete(...).copyWith(id: 12, name: "My name")
  /// ````
  EnvVarDelete call({
    Object? key = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return EnvVarDelete(
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

extension $EnvVarDeleteCopyWith on EnvVarDelete {
  /// Returns a callable class that can be used as follows: `instanceOfEnvVarDelete.copyWith(...)` or like so:`instanceOfEnvVarDelete.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EnvVarDeleteCWProxy get copyWith => _$EnvVarDeleteCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EnvVarDelete _$EnvVarDeleteFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EnvVarDelete', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['key']);
      final val = EnvVarDelete(
        key: $checkedConvert('key', (v) => v as String),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$EnvVarDeleteToJson(EnvVarDelete instance) =>
    <String, dynamic>{'key': instance.key, 'profile': ?instance.profile};
