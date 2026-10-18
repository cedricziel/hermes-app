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

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AgentPluginInstallBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AgentPluginInstallBody(...).copyWith(id: 12, name: "My name")
  /// ```
  AgentPluginInstallBody call({
    String identifier,
    bool? force,
    bool? enable,
    String? catalogName,
    String? ref,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfAgentPluginInstallBody.copyWith(...)` or call `instanceOfAgentPluginInstallBody.copyWith.fieldName(value)` for a single field.
class _$AgentPluginInstallBodyCWProxyImpl
    implements _$AgentPluginInstallBodyCWProxy {
  const _$AgentPluginInstallBodyCWProxyImpl(this._value);

  final AgentPluginInstallBody _value;

  @override
  AgentPluginInstallBody identifier(String identifier) =>
      call(identifier: identifier);

  @override
  AgentPluginInstallBody force(bool? force) => call(force: force);

  @override
  AgentPluginInstallBody enable(bool? enable) => call(enable: enable);

  @override
  AgentPluginInstallBody catalogName(String? catalogName) =>
      call(catalogName: catalogName);

  @override
  AgentPluginInstallBody ref(String? ref) => call(ref: ref);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `AgentPluginInstallBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// AgentPluginInstallBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  AgentPluginInstallBody call({
    Object? identifier = const $CopyWithPlaceholder(),
    Object? force = const $CopyWithPlaceholder(),
    Object? enable = const $CopyWithPlaceholder(),
    Object? catalogName = const $CopyWithPlaceholder(),
    Object? ref = const $CopyWithPlaceholder(),
  }) {
    return AgentPluginInstallBody(
      identifier:
          identifier == const $CopyWithPlaceholder() || identifier == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfAgentPluginInstallBody.copyWith(...)` or `instanceOfAgentPluginInstallBody.copyWith.fieldName(...)`.
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
