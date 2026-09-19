// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_toggle.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SkillToggleCWProxy {
  SkillToggle name(String name);

  SkillToggle enabled(bool enabled);

  SkillToggle profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkillToggle(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkillToggle(...).copyWith(id: 12, name: "My name")
  /// ````
  SkillToggle call({String name, bool enabled, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSkillToggle.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSkillToggle.copyWith.fieldName(...)`
class _$SkillToggleCWProxyImpl implements _$SkillToggleCWProxy {
  const _$SkillToggleCWProxyImpl(this._value);

  final SkillToggle _value;

  @override
  SkillToggle name(String name) => this(name: name);

  @override
  SkillToggle enabled(bool enabled) => this(enabled: enabled);

  @override
  SkillToggle profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SkillToggle(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SkillToggle(...).copyWith(id: 12, name: "My name")
  /// ````
  SkillToggle call({
    Object? name = const $CopyWithPlaceholder(),
    Object? enabled = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return SkillToggle(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      enabled: enabled == const $CopyWithPlaceholder()
          ? _value.enabled
          // ignore: cast_nullable_to_non_nullable
          : enabled as bool,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $SkillToggleCopyWith on SkillToggle {
  /// Returns a callable class that can be used as follows: `instanceOfSkillToggle.copyWith(...)` or like so:`instanceOfSkillToggle.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SkillToggleCWProxy get copyWith => _$SkillToggleCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SkillToggle _$SkillToggleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SkillToggle', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['name', 'enabled']);
      final val = SkillToggle(
        name: $checkedConvert('name', (v) => v as String),
        enabled: $checkedConvert('enabled', (v) => v as bool),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$SkillToggleToJson(SkillToggle instance) =>
    <String, dynamic>{
      'name': instance.name,
      'enabled': instance.enabled,
      'profile': ?instance.profile,
    };
