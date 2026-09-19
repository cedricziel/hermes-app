//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mcp_server_create.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MCPServerCreate {
  /// Returns a new [MCPServerCreate] instance.
  MCPServerCreate({
    required this.name,

    this.url,

    this.command,

    this.args = const [],

    this.env = const {},

    this.auth,

    this.bearerToken,

    this.profile,
  });

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'url', required: false, includeIfNull: false)
  final String? url;

  @JsonKey(name: r'command', required: false, includeIfNull: false)
  final String? command;

  @JsonKey(
    defaultValue: [],
    name: r'args',
    required: false,
    includeIfNull: false,
  )
  final List<String>? args;

  @JsonKey(
    defaultValue: {},
    name: r'env',
    required: false,
    includeIfNull: false,
  )
  final Map<String, String>? env;

  @JsonKey(name: r'auth', required: false, includeIfNull: false)
  final String? auth;

  @JsonKey(name: r'bearer_token', required: false, includeIfNull: false)
  final String? bearerToken;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MCPServerCreate &&
          other.name == name &&
          other.url == url &&
          other.command == command &&
          other.args == args &&
          other.env == env &&
          other.auth == auth &&
          other.bearerToken == bearerToken &&
          other.profile == profile;

  @override
  int get hashCode =>
      name.hashCode +
      (url == null ? 0 : url.hashCode) +
      (command == null ? 0 : command.hashCode) +
      args.hashCode +
      env.hashCode +
      (auth == null ? 0 : auth.hashCode) +
      (bearerToken == null ? 0 : bearerToken.hashCode) +
      (profile == null ? 0 : profile.hashCode);

  factory MCPServerCreate.fromJson(Map<String, dynamic> json) =>
      _$MCPServerCreateFromJson(json);

  Map<String, dynamic> toJson() => _$MCPServerCreateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
