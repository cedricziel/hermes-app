// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_catalog_install.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MCPCatalogInstallCWProxy {
  MCPCatalogInstall name(String name);

  MCPCatalogInstall env(Map<String, String>? env);

  MCPCatalogInstall enable(bool? enable);

  MCPCatalogInstall profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MCPCatalogInstall(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MCPCatalogInstall(...).copyWith(id: 12, name: "My name")
  /// ````
  MCPCatalogInstall call({
    String name,
    Map<String, String>? env,
    bool? enable,
    String? profile,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMCPCatalogInstall.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMCPCatalogInstall.copyWith.fieldName(...)`
class _$MCPCatalogInstallCWProxyImpl implements _$MCPCatalogInstallCWProxy {
  const _$MCPCatalogInstallCWProxyImpl(this._value);

  final MCPCatalogInstall _value;

  @override
  MCPCatalogInstall name(String name) => this(name: name);

  @override
  MCPCatalogInstall env(Map<String, String>? env) => this(env: env);

  @override
  MCPCatalogInstall enable(bool? enable) => this(enable: enable);

  @override
  MCPCatalogInstall profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MCPCatalogInstall(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MCPCatalogInstall(...).copyWith(id: 12, name: "My name")
  /// ````
  MCPCatalogInstall call({
    Object? name = const $CopyWithPlaceholder(),
    Object? env = const $CopyWithPlaceholder(),
    Object? enable = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return MCPCatalogInstall(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      env: env == const $CopyWithPlaceholder()
          ? _value.env
          // ignore: cast_nullable_to_non_nullable
          : env as Map<String, String>?,
      enable: enable == const $CopyWithPlaceholder()
          ? _value.enable
          // ignore: cast_nullable_to_non_nullable
          : enable as bool?,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $MCPCatalogInstallCopyWith on MCPCatalogInstall {
  /// Returns a callable class that can be used as follows: `instanceOfMCPCatalogInstall.copyWith(...)` or like so:`instanceOfMCPCatalogInstall.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MCPCatalogInstallCWProxy get copyWith =>
      _$MCPCatalogInstallCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MCPCatalogInstall _$MCPCatalogInstallFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MCPCatalogInstall', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['name']);
      final val = MCPCatalogInstall(
        name: $checkedConvert('name', (v) => v as String),
        env: $checkedConvert(
          'env',
          (v) =>
              (v as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, e as String),
              ) ??
              {},
        ),
        enable: $checkedConvert('enable', (v) => v as bool? ?? true),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$MCPCatalogInstallToJson(MCPCatalogInstall instance) =>
    <String, dynamic>{
      'name': instance.name,
      'env': ?instance.env,
      'enable': ?instance.enable,
      'profile': ?instance.profile,
    };
