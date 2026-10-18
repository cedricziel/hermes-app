// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'raw_config_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RawConfigUpdateCWProxy {
  RawConfigUpdate yamlText(String yamlText);

  RawConfigUpdate profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `RawConfigUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// RawConfigUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  RawConfigUpdate call({String yamlText, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfRawConfigUpdate.copyWith(...)` or call `instanceOfRawConfigUpdate.copyWith.fieldName(value)` for a single field.
class _$RawConfigUpdateCWProxyImpl implements _$RawConfigUpdateCWProxy {
  const _$RawConfigUpdateCWProxyImpl(this._value);

  final RawConfigUpdate _value;

  @override
  RawConfigUpdate yamlText(String yamlText) => call(yamlText: yamlText);

  @override
  RawConfigUpdate profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `RawConfigUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// RawConfigUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  RawConfigUpdate call({
    Object? yamlText = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return RawConfigUpdate(
      yamlText: yamlText == const $CopyWithPlaceholder() || yamlText == null
          ? _value.yamlText
          // ignore: cast_nullable_to_non_nullable
          : yamlText as String,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $RawConfigUpdateCopyWith on RawConfigUpdate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfRawConfigUpdate.copyWith(...)` or `instanceOfRawConfigUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RawConfigUpdateCWProxy get copyWith => _$RawConfigUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RawConfigUpdate _$RawConfigUpdateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('RawConfigUpdate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['yaml_text']);
      final val = RawConfigUpdate(
        yamlText: $checkedConvert('yaml_text', (v) => v as String),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'yamlText': 'yaml_text'});

Map<String, dynamic> _$RawConfigUpdateToJson(RawConfigUpdate instance) =>
    <String, dynamic>{
      'yaml_text': instance.yamlText,
      'profile': ?instance.profile,
    };
