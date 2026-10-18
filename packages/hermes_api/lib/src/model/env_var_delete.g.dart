// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env_var_delete.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EnvVarDeleteCWProxy {
  EnvVarDelete key(String key);

  EnvVarDelete profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `EnvVarDelete(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// EnvVarDelete(...).copyWith(id: 12, name: "My name")
  /// ```
  EnvVarDelete call({String key, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfEnvVarDelete.copyWith(...)` or call `instanceOfEnvVarDelete.copyWith.fieldName(value)` for a single field.
class _$EnvVarDeleteCWProxyImpl implements _$EnvVarDeleteCWProxy {
  const _$EnvVarDeleteCWProxyImpl(this._value);

  final EnvVarDelete _value;

  @override
  EnvVarDelete key(String key) => call(key: key);

  @override
  EnvVarDelete profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `EnvVarDelete(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// EnvVarDelete(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  EnvVarDelete call({
    Object? key = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return EnvVarDelete(
      key: key == const $CopyWithPlaceholder() || key == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfEnvVarDelete.copyWith(...)` or `instanceOfEnvVarDelete.copyWith.fieldName(...)`.
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
