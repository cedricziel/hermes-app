// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolset_env_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ToolsetEnvUpdateCWProxy {
  ToolsetEnvUpdate env(Map<String, String> env);

  ToolsetEnvUpdate profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ToolsetEnvUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ToolsetEnvUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  ToolsetEnvUpdate call({Map<String, String> env, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfToolsetEnvUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfToolsetEnvUpdate.copyWith.fieldName(...)`
class _$ToolsetEnvUpdateCWProxyImpl implements _$ToolsetEnvUpdateCWProxy {
  const _$ToolsetEnvUpdateCWProxyImpl(this._value);

  final ToolsetEnvUpdate _value;

  @override
  ToolsetEnvUpdate env(Map<String, String> env) => this(env: env);

  @override
  ToolsetEnvUpdate profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ToolsetEnvUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ToolsetEnvUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  ToolsetEnvUpdate call({
    Object? env = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ToolsetEnvUpdate(
      env: env == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfToolsetEnvUpdate.copyWith(...)` or like so:`instanceOfToolsetEnvUpdate.copyWith.fieldName(...)`.
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
