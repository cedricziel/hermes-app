//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'mcp_catalog_install.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MCPCatalogInstall {
  /// Returns a new [MCPCatalogInstall] instance.
  MCPCatalogInstall({
    required this.name,

    this.env = const {},

    this.enable = true,

    this.profile,
  });

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(
    defaultValue: {},
    name: r'env',
    required: false,
    includeIfNull: false,
  )
  final Map<String, String>? env;

  @JsonKey(
    defaultValue: true,
    name: r'enable',
    required: false,
    includeIfNull: false,
  )
  final bool? enable;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MCPCatalogInstall &&
          other.name == name &&
          other.env == env &&
          other.enable == enable &&
          other.profile == profile;

  @override
  int get hashCode =>
      name.hashCode +
      env.hashCode +
      enable.hashCode +
      (profile == null ? 0 : profile.hashCode);

  factory MCPCatalogInstall.fromJson(Map<String, dynamic> json) =>
      _$MCPCatalogInstallFromJson(json);

  Map<String, dynamic> toJson() => _$MCPCatalogInstallToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
