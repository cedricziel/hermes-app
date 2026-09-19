// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent_plugin_install_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$AgentPluginInstallBodyCWProxy {
  AgentPluginInstallBody identifier(String identifier);

  AgentPluginInstallBody force(bool? force);

  AgentPluginInstallBody enable(bool? enable);

  AgentPluginInstallBody catalogName(String? catalogName);

  AgentPluginInstallBody ref(String? ref);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AgentPluginInstallBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AgentPluginInstallBody(...).copyWith(id: 12, name: "My name")
  /// ````
  AgentPluginInstallBody call({
    String identifier,
    bool? force,
    bool? enable,
    String? catalogName,
    String? ref,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfAgentPluginInstallBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfAgentPluginInstallBody.copyWith.fieldName(...)`
class _$AgentPluginInstallBodyCWProxyImpl
    implements _$AgentPluginInstallBodyCWProxy {
  const _$AgentPluginInstallBodyCWProxyImpl(this._value);

  final AgentPluginInstallBody _value;

  @override
  AgentPluginInstallBody identifier(String identifier) =>
      this(identifier: identifier);

  @override
  AgentPluginInstallBody force(bool? force) => this(force: force);

  @override
  AgentPluginInstallBody enable(bool? enable) => this(enable: enable);

  @override
  AgentPluginInstallBody catalogName(String? catalogName) =>
      this(catalogName: catalogName);

  @override
  AgentPluginInstallBody ref(String? ref) => this(ref: ref);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `AgentPluginInstallBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// AgentPluginInstallBody(...).copyWith(id: 12, name: "My name")
  /// ````
  AgentPluginInstallBody call({
    Object? identifier = const $CopyWithPlaceholder(),
    Object? force = const $CopyWithPlaceholder(),
    Object? enable = const $CopyWithPlaceholder(),
    Object? catalogName = const $CopyWithPlaceholder(),
    Object? ref = const $CopyWithPlaceholder(),
  }) {
    return AgentPluginInstallBody(
      identifier: identifier == const $CopyWithPlaceholder()
          ? _value.identifier
          // ignore: cast_nullable_to_non_nullable
          : identifier as String,
      force: force == const $CopyWithPlaceholder()
          ? _value.force
          // ignore: cast_nullable_to_non_nullable
          : force as bool?,
      enable: enable == const $CopyWithPlaceholder()
          ? _value.enable
          // ignore: cast_nullable_to_non_nullable
          : enable as bool?,
      catalogName: catalogName == const $CopyWithPlaceholder()
          ? _value.catalogName
          // ignore: cast_nullable_to_non_nullable
          : catalogName as String?,
      ref: ref == const $CopyWithPlaceholder()
          ? _value.ref
          // ignore: cast_nullable_to_non_nullable
          : ref as String?,
    );
  }
}

extension $AgentPluginInstallBodyCopyWith on AgentPluginInstallBody {
  /// Returns a callable class that can be used as follows: `instanceOfAgentPluginInstallBody.copyWith(...)` or like so:`instanceOfAgentPluginInstallBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$AgentPluginInstallBodyCWProxy get copyWith =>
      _$AgentPluginInstallBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

AgentPluginInstallBody _$AgentPluginInstallBodyFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('AgentPluginInstallBody', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['identifier']);
  final val = AgentPluginInstallBody(
    identifier: $checkedConvert('identifier', (v) => v as String),
    force: $checkedConvert('force', (v) => v as bool? ?? false),
    enable: $checkedConvert('enable', (v) => v as bool? ?? true),
    catalogName: $checkedConvert('catalog_name', (v) => v as String?),
    ref: $checkedConvert('ref', (v) => v as String?),
  );
  return val;
}, fieldKeyMap: const {'catalogName': 'catalog_name'});

Map<String, dynamic> _$AgentPluginInstallBodyToJson(
  AgentPluginInstallBody instance,
) => <String, dynamic>{
  'identifier': instance.identifier,
  'force': ?instance.force,
  'enable': ?instance.enable,
  'catalog_name': ?instance.catalogName,
  'ref': ?instance.ref,
};
