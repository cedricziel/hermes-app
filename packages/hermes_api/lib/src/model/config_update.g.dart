// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ConfigUpdateCWProxy {
  ConfigUpdate config(Map<String, Object> config);

  ConfigUpdate profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConfigUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConfigUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  ConfigUpdate call({Map<String, Object> config, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfConfigUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfConfigUpdate.copyWith.fieldName(...)`
class _$ConfigUpdateCWProxyImpl implements _$ConfigUpdateCWProxy {
  const _$ConfigUpdateCWProxyImpl(this._value);

  final ConfigUpdate _value;

  @override
  ConfigUpdate config(Map<String, Object> config) => this(config: config);

  @override
  ConfigUpdate profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ConfigUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ConfigUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  ConfigUpdate call({
    Object? config = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ConfigUpdate(
      config: config == const $CopyWithPlaceholder()
          ? _value.config
          // ignore: cast_nullable_to_non_nullable
          : config as Map<String, Object>,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $ConfigUpdateCopyWith on ConfigUpdate {
  /// Returns a callable class that can be used as follows: `instanceOfConfigUpdate.copyWith(...)` or like so:`instanceOfConfigUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ConfigUpdateCWProxy get copyWith => _$ConfigUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfigUpdate _$ConfigUpdateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ConfigUpdate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['config']);
      final val = ConfigUpdate(
        config: $checkedConvert(
          'config',
          (v) => (v as Map<String, dynamic>).map(
            (k, e) => MapEntry(k, e as Object),
          ),
        ),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ConfigUpdateToJson(ConfigUpdate instance) =>
    <String, dynamic>{'config': instance.config, 'profile': ?instance.profile};
