// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'raw_config_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RawConfigUpdateCWProxy {
  RawConfigUpdate yamlText(String yamlText);

  RawConfigUpdate profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RawConfigUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RawConfigUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  RawConfigUpdate call({String yamlText, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfRawConfigUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfRawConfigUpdate.copyWith.fieldName(...)`
class _$RawConfigUpdateCWProxyImpl implements _$RawConfigUpdateCWProxy {
  const _$RawConfigUpdateCWProxyImpl(this._value);

  final RawConfigUpdate _value;

  @override
  RawConfigUpdate yamlText(String yamlText) => this(yamlText: yamlText);

  @override
  RawConfigUpdate profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `RawConfigUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// RawConfigUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  RawConfigUpdate call({
    Object? yamlText = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return RawConfigUpdate(
      yamlText: yamlText == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfRawConfigUpdate.copyWith(...)` or like so:`instanceOfRawConfigUpdate.copyWith.fieldName(...)`.
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
