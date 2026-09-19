// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_servers_replace.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MCPServersReplaceCWProxy {
  MCPServersReplace servers(Map<String, Map<String, Object>>? servers);

  MCPServersReplace profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MCPServersReplace(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MCPServersReplace(...).copyWith(id: 12, name: "My name")
  /// ````
  MCPServersReplace call({
    Map<String, Map<String, Object>>? servers,
    String? profile,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMCPServersReplace.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMCPServersReplace.copyWith.fieldName(...)`
class _$MCPServersReplaceCWProxyImpl implements _$MCPServersReplaceCWProxy {
  const _$MCPServersReplaceCWProxyImpl(this._value);

  final MCPServersReplace _value;

  @override
  MCPServersReplace servers(Map<String, Map<String, Object>>? servers) =>
      this(servers: servers);

  @override
  MCPServersReplace profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MCPServersReplace(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MCPServersReplace(...).copyWith(id: 12, name: "My name")
  /// ````
  MCPServersReplace call({
    Object? servers = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return MCPServersReplace(
      servers: servers == const $CopyWithPlaceholder()
          ? _value.servers
          // ignore: cast_nullable_to_non_nullable
          : servers as Map<String, Map<String, Object>>?,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $MCPServersReplaceCopyWith on MCPServersReplace {
  /// Returns a callable class that can be used as follows: `instanceOfMCPServersReplace.copyWith(...)` or like so:`instanceOfMCPServersReplace.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MCPServersReplaceCWProxy get copyWith =>
      _$MCPServersReplaceCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MCPServersReplace _$MCPServersReplaceFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MCPServersReplace', json, ($checkedConvert) {
      final val = MCPServersReplace(
        servers: $checkedConvert(
          'servers',
          (v) =>
              (v as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(
                  k,
                  (e as Map<String, dynamic>).map(
                    (k, e) => MapEntry(k, e as Object),
                  ),
                ),
              ) ??
              {},
        ),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$MCPServersReplaceToJson(MCPServersReplace instance) =>
    <String, dynamic>{
      'servers': ?instance.servers,
      'profile': ?instance.profile,
    };
