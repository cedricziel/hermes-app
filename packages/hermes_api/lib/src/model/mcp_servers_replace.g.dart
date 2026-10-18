// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_servers_replace.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MCPServersReplaceCWProxy {
  MCPServersReplace servers(Map<String, Map<String, Object>>? servers);

  MCPServersReplace profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MCPServersReplace(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MCPServersReplace(...).copyWith(id: 12, name: "My name")
  /// ```
  MCPServersReplace call({
    Map<String, Map<String, Object>>? servers,
    String? profile,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMCPServersReplace.copyWith(...)` or call `instanceOfMCPServersReplace.copyWith.fieldName(value)` for a single field.
class _$MCPServersReplaceCWProxyImpl implements _$MCPServersReplaceCWProxy {
  const _$MCPServersReplaceCWProxyImpl(this._value);

  final MCPServersReplace _value;

  @override
  MCPServersReplace servers(Map<String, Map<String, Object>>? servers) =>
      call(servers: servers);

  @override
  MCPServersReplace profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MCPServersReplace(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MCPServersReplace(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMCPServersReplace.copyWith(...)` or `instanceOfMCPServersReplace.copyWith.fieldName(...)`.
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
