// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'toolset_provider_select.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ToolsetProviderSelectCWProxy {
  ToolsetProviderSelect provider(String provider);

  ToolsetProviderSelect capability(String? capability);

  ToolsetProviderSelect profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ToolsetProviderSelect(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ToolsetProviderSelect(...).copyWith(id: 12, name: "My name")
  /// ````
  ToolsetProviderSelect call({
    String provider,
    String? capability,
    String? profile,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfToolsetProviderSelect.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfToolsetProviderSelect.copyWith.fieldName(...)`
class _$ToolsetProviderSelectCWProxyImpl
    implements _$ToolsetProviderSelectCWProxy {
  const _$ToolsetProviderSelectCWProxyImpl(this._value);

  final ToolsetProviderSelect _value;

  @override
  ToolsetProviderSelect provider(String provider) => this(provider: provider);

  @override
  ToolsetProviderSelect capability(String? capability) =>
      this(capability: capability);

  @override
  ToolsetProviderSelect profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ToolsetProviderSelect(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ToolsetProviderSelect(...).copyWith(id: 12, name: "My name")
  /// ````
  ToolsetProviderSelect call({
    Object? provider = const $CopyWithPlaceholder(),
    Object? capability = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ToolsetProviderSelect(
      provider: provider == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfToolsetProviderSelect.copyWith(...)` or like so:`instanceOfToolsetProviderSelect.copyWith.fieldName(...)`.
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
