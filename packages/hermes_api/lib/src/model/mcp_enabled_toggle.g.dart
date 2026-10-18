// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_enabled_toggle.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MCPEnabledToggleCWProxy {
  MCPEnabledToggle enabled(bool enabled);

  MCPEnabledToggle profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MCPEnabledToggle(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MCPEnabledToggle(...).copyWith(id: 12, name: "My name")
  /// ```
  MCPEnabledToggle call({bool enabled, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMCPEnabledToggle.copyWith(...)` or call `instanceOfMCPEnabledToggle.copyWith.fieldName(value)` for a single field.
class _$MCPEnabledToggleCWProxyImpl implements _$MCPEnabledToggleCWProxy {
  const _$MCPEnabledToggleCWProxyImpl(this._value);

  final MCPEnabledToggle _value;

  @override
  MCPEnabledToggle enabled(bool enabled) => call(enabled: enabled);

  @override
  MCPEnabledToggle profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MCPEnabledToggle(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MCPEnabledToggle(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MCPEnabledToggle call({
    Object? enabled = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return MCPEnabledToggle(
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

extension $MCPEnabledToggleCopyWith on MCPEnabledToggle {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMCPEnabledToggle.copyWith(...)` or `instanceOfMCPEnabledToggle.copyWith.fieldName(...)`.
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
