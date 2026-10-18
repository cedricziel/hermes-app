// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'env_var_reveal.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EnvVarRevealCWProxy {
  EnvVarReveal key(String key);

  EnvVarReveal profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `EnvVarReveal(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// EnvVarReveal(...).copyWith(id: 12, name: "My name")
  /// ```
  EnvVarReveal call({String key, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfEnvVarReveal.copyWith(...)` or call `instanceOfEnvVarReveal.copyWith.fieldName(value)` for a single field.
class _$EnvVarRevealCWProxyImpl implements _$EnvVarRevealCWProxy {
  const _$EnvVarRevealCWProxyImpl(this._value);

  final EnvVarReveal _value;

  @override
  EnvVarReveal key(String key) => call(key: key);

  @override
  EnvVarReveal profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `EnvVarReveal(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// EnvVarReveal(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  EnvVarReveal call({
    Object? key = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return EnvVarReveal(
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

extension $EnvVarRevealCopyWith on EnvVarReveal {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfEnvVarReveal.copyWith(...)` or `instanceOfEnvVarReveal.copyWith.fieldName(...)`.
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
