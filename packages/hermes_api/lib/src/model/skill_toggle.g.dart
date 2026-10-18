// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'skill_toggle.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SkillToggleCWProxy {
  SkillToggle name(String name);

  SkillToggle enabled(bool enabled);

  SkillToggle profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SkillToggle(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SkillToggle(...).copyWith(id: 12, name: "My name")
  /// ```
  SkillToggle call({String name, bool enabled, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSkillToggle.copyWith(...)` or call `instanceOfSkillToggle.copyWith.fieldName(value)` for a single field.
class _$SkillToggleCWProxyImpl implements _$SkillToggleCWProxy {
  const _$SkillToggleCWProxyImpl(this._value);

  final SkillToggle _value;

  @override
  SkillToggle name(String name) => call(name: name);

  @override
  SkillToggle enabled(bool enabled) => call(enabled: enabled);

  @override
  SkillToggle profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `SkillToggle(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// SkillToggle(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  SkillToggle call({
    Object? name = const $CopyWithPlaceholder(),
    Object? enabled = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return SkillToggle(
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      enabled: enabled == const $CopyWithPlaceholder() || enabled == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSkillToggle.copyWith(...)` or `instanceOfSkillToggle.copyWith.fieldName(...)`.
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
