// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_enabled_toggle.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MCPEnabledToggleCWProxy {
  MCPEnabledToggle enabled(bool enabled);

  MCPEnabledToggle profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MCPEnabledToggle(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MCPEnabledToggle(...).copyWith(id: 12, name: "My name")
  /// ````
  MCPEnabledToggle call({bool enabled, String? profile});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMCPEnabledToggle.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMCPEnabledToggle.copyWith.fieldName(...)`
class _$MCPEnabledToggleCWProxyImpl implements _$MCPEnabledToggleCWProxy {
  const _$MCPEnabledToggleCWProxyImpl(this._value);

  final MCPEnabledToggle _value;

  @override
  MCPEnabledToggle enabled(bool enabled) => this(enabled: enabled);

  @override
  MCPEnabledToggle profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MCPEnabledToggle(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MCPEnabledToggle(...).copyWith(id: 12, name: "My name")
  /// ````
  MCPEnabledToggle call({
    Object? enabled = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return MCPEnabledToggle(
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

extension $MCPEnabledToggleCopyWith on MCPEnabledToggle {
  /// Returns a callable class that can be used as follows: `instanceOfMCPEnabledToggle.copyWith(...)` or like so:`instanceOfMCPEnabledToggle.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MCPEnabledToggleCWProxy get copyWith => _$MCPEnabledToggleCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MCPEnabledToggle _$MCPEnabledToggleFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MCPEnabledToggle', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['enabled']);
      final val = MCPEnabledToggle(
        enabled: $checkedConvert('enabled', (v) => v as bool),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$MCPEnabledToggleToJson(MCPEnabledToggle instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'profile': ?instance.profile,
    };
