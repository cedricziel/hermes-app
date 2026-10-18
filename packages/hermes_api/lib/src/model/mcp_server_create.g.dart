// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_server_create.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MCPServerCreateCWProxy {
  MCPServerCreate name(String name);

  MCPServerCreate url(String? url);

  MCPServerCreate command(String? command);

  MCPServerCreate args(List<String>? args);

  MCPServerCreate env(Map<String, String>? env);

  MCPServerCreate auth(String? auth);

  MCPServerCreate bearerToken(String? bearerToken);

  MCPServerCreate profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MCPServerCreate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MCPServerCreate(...).copyWith(id: 12, name: "My name")
  /// ```
  MCPServerCreate call({
    String name,
    String? url,
    String? command,
    List<String>? args,
    Map<String, String>? env,
    String? auth,
    String? bearerToken,
    String? profile,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMCPServerCreate.copyWith(...)` or call `instanceOfMCPServerCreate.copyWith.fieldName(value)` for a single field.
class _$MCPServerCreateCWProxyImpl implements _$MCPServerCreateCWProxy {
  const _$MCPServerCreateCWProxyImpl(this._value);

  final MCPServerCreate _value;

  @override
  MCPServerCreate name(String name) => call(name: name);

  @override
  MCPServerCreate url(String? url) => call(url: url);

  @override
  MCPServerCreate command(String? command) => call(command: command);

  @override
  MCPServerCreate args(List<String>? args) => call(args: args);

  @override
  MCPServerCreate env(Map<String, String>? env) => call(env: env);

  @override
  MCPServerCreate auth(String? auth) => call(auth: auth);

  @override
  MCPServerCreate bearerToken(String? bearerToken) =>
      call(bearerToken: bearerToken);

  @override
  MCPServerCreate profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MCPServerCreate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MCPServerCreate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MCPServerCreate call({
    Object? name = const $CopyWithPlaceholder(),
    Object? url = const $CopyWithPlaceholder(),
    Object? command = const $CopyWithPlaceholder(),
    Object? args = const $CopyWithPlaceholder(),
    Object? env = const $CopyWithPlaceholder(),
    Object? auth = const $CopyWithPlaceholder(),
    Object? bearerToken = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return MCPServerCreate(
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      url: url == const $CopyWithPlaceholder()
          ? _value.url
          // ignore: cast_nullable_to_non_nullable
          : url as String?,
      command: command == const $CopyWithPlaceholder()
          ? _value.command
          // ignore: cast_nullable_to_non_nullable
          : command as String?,
      args: args == const $CopyWithPlaceholder()
          ? _value.args
          // ignore: cast_nullable_to_non_nullable
          : args as List<String>?,
      env: env == const $CopyWithPlaceholder()
          ? _value.env
          // ignore: cast_nullable_to_non_nullable
          : env as Map<String, String>?,
      auth: auth == const $CopyWithPlaceholder()
          ? _value.auth
          // ignore: cast_nullable_to_non_nullable
          : auth as String?,
      bearerToken: bearerToken == const $CopyWithPlaceholder()
          ? _value.bearerToken
          // ignore: cast_nullable_to_non_nullable
          : bearerToken as String?,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $MCPServerCreateCopyWith on MCPServerCreate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMCPServerCreate.copyWith(...)` or `instanceOfMCPServerCreate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MCPServerCreateCWProxy get copyWith => _$MCPServerCreateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MCPServerCreate _$MCPServerCreateFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MCPServerCreate', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['name']);
      final val = MCPServerCreate(
        name: $checkedConvert('name', (v) => v as String),
        url: $checkedConvert('url', (v) => v as String?),
        command: $checkedConvert('command', (v) => v as String?),
        args: $checkedConvert(
          'args',
          (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        ),
        env: $checkedConvert(
          'env',
          (v) =>
              (v as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, e as String),
              ) ??
              {},
        ),
        auth: $checkedConvert('auth', (v) => v as String?),
        bearerToken: $checkedConvert('bearer_token', (v) => v as String?),
        profile: $checkedConvert('profile', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'bearerToken': 'bearer_token'});

Map<String, dynamic> _$MCPServerCreateToJson(MCPServerCreate instance) =>
    <String, dynamic>{
      'name': instance.name,
      'url': ?instance.url,
      'command': ?instance.command,
      'args': ?instance.args,
      'env': ?instance.env,
      'auth': ?instance.auth,
      'bearer_token': ?instance.bearerToken,
      'profile': ?instance.profile,
    };
