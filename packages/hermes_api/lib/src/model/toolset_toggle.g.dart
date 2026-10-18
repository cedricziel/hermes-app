// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolset_toggle.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ToolsetToggleCWProxy {
  ToolsetToggle enabled(bool enabled);

  ToolsetToggle profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ToolsetToggle(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ToolsetToggle(...).copyWith(id: 12, name: "My name")
  /// ```
  ToolsetToggle call({bool enabled, String? profile});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfToolsetToggle.copyWith(...)` or call `instanceOfToolsetToggle.copyWith.fieldName(value)` for a single field.
class _$ToolsetToggleCWProxyImpl implements _$ToolsetToggleCWProxy {
  const _$ToolsetToggleCWProxyImpl(this._value);

  final ToolsetToggle _value;

  @override
  ToolsetToggle enabled(bool enabled) => call(enabled: enabled);

  @override
  ToolsetToggle profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ToolsetToggle(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ToolsetToggle(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ToolsetToggle call({
    Object? enabled = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ToolsetToggle(
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

extension $ToolsetToggleCopyWith on ToolsetToggle {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfToolsetToggle.copyWith(...)` or `instanceOfToolsetToggle.copyWith.fieldName(...)`.
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
