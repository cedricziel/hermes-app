// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolset_toggle.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ToolsetToggleCWProxy {
  ToolsetToggle enabled(bool enabled);

  ToolsetToggle profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ToolsetToggle(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ToolsetToggle(...).copyWith(id: 12, name: "My name")
  /// ````
  ToolsetToggle call({bool enabled, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfToolsetToggle.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfToolsetToggle.copyWith.fieldName(...)`
class _$ToolsetToggleCWProxyImpl implements _$ToolsetToggleCWProxy {
  const _$ToolsetToggleCWProxyImpl(this._value);

  final ToolsetToggle _value;

  @override
  ToolsetToggle enabled(bool enabled) => this(enabled: enabled);

  @override
  ToolsetToggle profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ToolsetToggle(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ToolsetToggle(...).copyWith(id: 12, name: "My name")
  /// ````
  ToolsetToggle call({
    Object? enabled = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ToolsetToggle(
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

extension $ToolsetToggleCopyWith on ToolsetToggle {
  /// Returns a callable class that can be used as follows: `instanceOfToolsetToggle.copyWith(...)` or like so:`instanceOfToolsetToggle.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ToolsetToggleCWProxy get copyWith => _$ToolsetToggleCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ToolsetToggle _$ToolsetToggleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ToolsetToggle', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['enabled']);
      final val = ToolsetToggle(
        enabled: $checkedConvert('enabled', (v) => v as bool),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ToolsetToggleToJson(ToolsetToggle instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'profile': ?instance.profile,
    };
