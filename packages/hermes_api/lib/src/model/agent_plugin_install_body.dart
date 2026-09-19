//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'agent_plugin_install_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AgentPluginInstallBody {
  /// Returns a new [AgentPluginInstallBody] instance.
  AgentPluginInstallBody({
    required this.identifier,

    this.force = false,

    this.enable = true,

    this.catalogName,

    this.ref,
  });

  @JsonKey(name: r'identifier', required: true, includeIfNull: false)
  final String identifier;

  @JsonKey(
    defaultValue: false,
    name: r'force',
    required: false,
    includeIfNull: false,
  )
  final bool? force;

  @JsonKey(
    defaultValue: true,
    name: r'enable',
    required: false,
    includeIfNull: false,
  )
  final bool? enable;

  @JsonKey(name: r'catalog_name', required: false, includeIfNull: false)
  final String? catalogName;

  @JsonKey(name: r'ref', required: false, includeIfNull: false)
  final String? ref;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AgentPluginInstallBody &&
          other.identifier == identifier &&
          other.force == force &&
          other.enable == enable &&
          other.catalogName == catalogName &&
          other.ref == ref;

  @override
  int get hashCode =>
      identifier.hashCode +
      force.hashCode +
      enable.hashCode +
      (catalogName == null ? 0 : catalogName.hashCode) +
      (ref == null ? 0 : ref.hashCode);

  factory AgentPluginInstallBody.fromJson(Map<String, dynamic> json) =>
      _$AgentPluginInstallBodyFromJson(json);

  Map<String, dynamic> toJson() => _$AgentPluginInstallBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
