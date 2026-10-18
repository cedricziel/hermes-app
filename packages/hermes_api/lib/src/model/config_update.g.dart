// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ConfigUpdateCWProxy {
  ConfigUpdate config(Map<String, Object> config);

  ConfigUpdate profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ConfigUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ConfigUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  ConfigUpdate call({Map<String, Object> config, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfConfigUpdate.copyWith(...)` or call `instanceOfConfigUpdate.copyWith.fieldName(value)` for a single field.
class _$ConfigUpdateCWProxyImpl implements _$ConfigUpdateCWProxy {
  const _$ConfigUpdateCWProxyImpl(this._value);

  final ConfigUpdate _value;

  @override
  ConfigUpdate config(Map<String, Object> config) => call(config: config);

  @override
  ConfigUpdate profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ConfigUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ConfigUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ConfigUpdate call({
    Object? config = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ConfigUpdate(
      config: config == const $CopyWithPlaceholder() || config == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfConfigUpdate.copyWith(...)` or `instanceOfConfigUpdate.copyWith.fieldName(...)`.
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
