//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mcp_servers_replace.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MCPServersReplace {
  /// Returns a new [MCPServersReplace] instance.
  MCPServersReplace({this.servers = const {}, this.profile});

  @JsonKey(
    defaultValue: {},
    name: r'servers',
    required: false,
    includeIfNull: false,
  )
  final Map<String, Map<String, Object>>? servers;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MCPServersReplace &&
          other.servers == servers &&
          other.profile == profile;

  @override
  int get hashCode =>
      servers.hashCode + (profile == null ? 0 : profile.hashCode);

  factory MCPServersReplace.fromJson(Map<String, dynamic> json) =>
      _$MCPServersReplaceFromJson(json);

  Map<String, dynamic> toJson() => _$MCPServersReplaceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
