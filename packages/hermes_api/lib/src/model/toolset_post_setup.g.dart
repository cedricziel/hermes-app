// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolset_post_setup.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ToolsetPostSetupCWProxy {
  ToolsetPostSetup key(String key);

  ToolsetPostSetup profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ToolsetPostSetup(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ToolsetPostSetup(...).copyWith(id: 12, name: "My name")
  /// ````
  ToolsetPostSetup call({String key, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfToolsetPostSetup.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfToolsetPostSetup.copyWith.fieldName(...)`
class _$ToolsetPostSetupCWProxyImpl implements _$ToolsetPostSetupCWProxy {
  const _$ToolsetPostSetupCWProxyImpl(this._value);

  final ToolsetPostSetup _value;

  @override
  ToolsetPostSetup key(String key) => this(key: key);

  @override
  ToolsetPostSetup profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ToolsetPostSetup(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ToolsetPostSetup(...).copyWith(id: 12, name: "My name")
  /// ````
  ToolsetPostSetup call({
    Object? key = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ToolsetPostSetup(
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

extension $ToolsetPostSetupCopyWith on ToolsetPostSetup {
  /// Returns a callable class that can be used as follows: `instanceOfToolsetPostSetup.copyWith(...)` or like so:`instanceOfToolsetPostSetup.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ToolsetPostSetupCWProxy get copyWith => _$ToolsetPostSetupCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ToolsetPostSetup _$ToolsetPostSetupFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ToolsetPostSetup', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['key']);
      final val = ToolsetPostSetup(
        key: $checkedConvert('key', (v) => v as String),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ToolsetPostSetupToJson(ToolsetPostSetup instance) =>
    <String, dynamic>{'key': instance.key, 'profile': ?instance.profile};
