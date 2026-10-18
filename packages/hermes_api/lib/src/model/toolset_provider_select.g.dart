// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolset_provider_select.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ToolsetProviderSelectCWProxy {
  ToolsetProviderSelect provider(String provider);

  ToolsetProviderSelect capability(String? capability);

  ToolsetProviderSelect profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ToolsetProviderSelect(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ToolsetProviderSelect(...).copyWith(id: 12, name: "My name")
  /// ```
  ToolsetProviderSelect call({
    String provider,
    String? capability,
    String? profile,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfToolsetProviderSelect.copyWith(...)` or call `instanceOfToolsetProviderSelect.copyWith.fieldName(value)` for a single field.
class _$ToolsetProviderSelectCWProxyImpl
    implements _$ToolsetProviderSelectCWProxy {
  const _$ToolsetProviderSelectCWProxyImpl(this._value);

  final ToolsetProviderSelect _value;

  @override
  ToolsetProviderSelect provider(String provider) => call(provider: provider);

  @override
  ToolsetProviderSelect capability(String? capability) =>
      call(capability: capability);

  @override
  ToolsetProviderSelect profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ToolsetProviderSelect(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ToolsetProviderSelect(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ToolsetProviderSelect call({
    Object? provider = const $CopyWithPlaceholder(),
    Object? capability = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ToolsetProviderSelect(
      provider: provider == const $CopyWithPlaceholder() || provider == null
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String,
      capability: capability == const $CopyWithPlaceholder()
          ? _value.capability
          // ignore: cast_nullable_to_non_nullable
          : capability as String?,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $ToolsetProviderSelectCopyWith on ToolsetProviderSelect {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfToolsetProviderSelect.copyWith(...)` or `instanceOfToolsetProviderSelect.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ToolsetProviderSelectCWProxy get copyWith =>
      _$ToolsetProviderSelectCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ToolsetProviderSelect _$ToolsetProviderSelectFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ToolsetProviderSelect', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['provider']);
  final val = ToolsetProviderSelect(
    provider: $checkedConvert('provider', (v) => v as String),
    capability: $checkedConvert('capability', (v) => v as String?),
    profile: $checkedConvert('profile', (v) => v as String?),
  );
  return val;
});

Map<String, dynamic> _$ToolsetProviderSelectToJson(
  ToolsetProviderSelect instance,
) => <String, dynamic>{
  'provider': instance.provider,
  'capability': ?instance.capability,
  'profile': ?instance.profile,
};
