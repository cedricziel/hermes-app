//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:hermes_api/src/model/mcp_server_create.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_create.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfileCreate {
  /// Returns a new [ProfileCreate] instance.
  ProfileCreate({
    required this.name,

    this.cloneFrom,

    this.cloneFromDefault = false,

    this.cloneAll = false,

    this.cloneChannels = false,

    this.noSkills = false,

    this.description,

    this.provider,

    this.model,

    this.mcpServers = const [],

    this.keepSkills = const [],

    this.hubSkills = const [],
  });

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'clone_from', required: false, includeIfNull: false)
  final String? cloneFrom;

  @JsonKey(
    defaultValue: false,
    name: r'clone_from_default',
    required: false,
    includeIfNull: false,
  )
  final bool? cloneFromDefault;

  @JsonKey(
    defaultValue: false,
    name: r'clone_all',
    required: false,
    includeIfNull: false,
  )
  final bool? cloneAll;

  @JsonKey(
    defaultValue: false,
    name: r'clone_channels',
    required: false,
    includeIfNull: false,
  )
  final bool? cloneChannels;

  @JsonKey(
    defaultValue: false,
    name: r'no_skills',
    required: false,
    includeIfNull: false,
  )
  final bool? noSkills;

  @JsonKey(name: r'description', required: false, includeIfNull: false)
  final String? description;

  @JsonKey(name: r'provider', required: false, includeIfNull: false)
  final String? provider;

  @JsonKey(name: r'model', required: false, includeIfNull: false)
  final String? model;

  @JsonKey(
    defaultValue: [],
    name: r'mcp_servers',
    required: false,
    includeIfNull: false,
  )
  final List<MCPServerCreate>? mcpServers;

  @JsonKey(
    defaultValue: [],
    name: r'keep_skills',
    required: false,
    includeIfNull: false,
  )
  final List<String>? keepSkills;

  @JsonKey(
    defaultValue: [],
    name: r'hub_skills',
    required: false,
    includeIfNull: false,
  )
  final List<String>? hubSkills;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileCreate &&
          other.name == name &&
          other.cloneFrom == cloneFrom &&
          other.cloneFromDefault == cloneFromDefault &&
          other.cloneAll == cloneAll &&
          other.cloneChannels == cloneChannels &&
          other.noSkills == noSkills &&
          other.description == description &&
          other.provider == provider &&
          other.model == model &&
          other.mcpServers == mcpServers &&
          other.keepSkills == keepSkills &&
          other.hubSkills == hubSkills;

  @override
  int get hashCode =>
      name.hashCode +
      (cloneFrom == null ? 0 : cloneFrom.hashCode) +
      cloneFromDefault.hashCode +
      cloneAll.hashCode +
      cloneChannels.hashCode +
      noSkills.hashCode +
      (description == null ? 0 : description.hashCode) +
      (provider == null ? 0 : provider.hashCode) +
      (model == null ? 0 : model.hashCode) +
      mcpServers.hashCode +
      keepSkills.hashCode +
      hubSkills.hashCode;

  factory ProfileCreate.fromJson(Map<String, dynamic> json) =>
      _$ProfileCreateFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileCreateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
