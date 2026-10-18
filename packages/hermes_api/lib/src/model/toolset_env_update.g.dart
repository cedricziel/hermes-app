// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolset_env_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ToolsetEnvUpdateCWProxy {
  ToolsetEnvUpdate env(Map<String, String> env);

  ToolsetEnvUpdate profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ToolsetEnvUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ToolsetEnvUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  ToolsetEnvUpdate call({Map<String, String> env, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfToolsetEnvUpdate.copyWith(...)` or call `instanceOfToolsetEnvUpdate.copyWith.fieldName(value)` for a single field.
class _$ToolsetEnvUpdateCWProxyImpl implements _$ToolsetEnvUpdateCWProxy {
  const _$ToolsetEnvUpdateCWProxyImpl(this._value);

  final ToolsetEnvUpdate _value;

  @override
  ToolsetEnvUpdate env(Map<String, String> env) => call(env: env);

  @override
  ToolsetEnvUpdate profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ToolsetEnvUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ToolsetEnvUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ToolsetEnvUpdate call({
    Object? env = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ToolsetEnvUpdate(
      env: env == const $CopyWithPlaceholder() || env == null
          ? _value.env
          // ignore: cast_nullable_to_non_nullable
          : env as Map<String, String>,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $ToolsetEnvUpdateCopyWith on ToolsetEnvUpdate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfToolsetEnvUpdate.copyWith(...)` or `instanceOfToolsetEnvUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ToolsetEnvUpdateCWProxy get copyWith => _$ToolsetEnvUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ToolsetEnvUpdate _$ToolsetEnvUpdateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ToolsetEnvUpdate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['env']);
      final val = ToolsetEnvUpdate(
        env: $checkedConvert('env', (v) => Map<String, String>.from(v as Map)),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ToolsetEnvUpdateToJson(ToolsetEnvUpdate instance) =>
    <String, dynamic>{'env': instance.env, 'profile': ?instance.profile};
