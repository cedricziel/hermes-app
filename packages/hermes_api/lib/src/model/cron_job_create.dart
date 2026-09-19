//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'cron_job_create.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CronJobCreate {
  /// Returns a new [CronJobCreate] instance.
  CronJobCreate({
    this.paused = false,

    this.pausedReason,

    this.prompt = '',

    required this.schedule,

    this.name = '',

    this.deliver = 'local',

    this.skills,

    this.model,

    this.provider,

    this.baseUrl,

    this.script,

    this.contextFrom,

    this.enabledToolsets,

    this.workdir,

    this.noAgent = false,
  });

  @JsonKey(
    defaultValue: false,
    name: r'paused',
    required: false,
    includeIfNull: false,
  )
  final bool? paused;

  @JsonKey(name: r'paused_reason', required: false, includeIfNull: false)
  final String? pausedReason;

  @JsonKey(
    defaultValue: '',
    name: r'prompt',
    required: false,
    includeIfNull: false,
  )
  final String? prompt;

  @JsonKey(name: r'schedule', required: true, includeIfNull: false)
  final String schedule;

  @JsonKey(
    defaultValue: '',
    name: r'name',
    required: false,
    includeIfNull: false,
  )
  final String? name;

  @JsonKey(
    defaultValue: 'local',
    name: r'deliver',
    required: false,
    includeIfNull: false,
  )
  final String? deliver;

  @JsonKey(name: r'skills', required: false, includeIfNull: false)
  final List<String>? skills;

  @JsonKey(name: r'model', required: false, includeIfNull: false)
  final String? model;

  @JsonKey(name: r'provider', required: false, includeIfNull: false)
  final String? provider;

  @JsonKey(name: r'base_url', required: false, includeIfNull: false)
  final String? baseUrl;

  @JsonKey(name: r'script', required: false, includeIfNull: false)
  final String? script;

  @JsonKey(name: r'context_from', required: false, includeIfNull: false)
  final Object? contextFrom;

  @JsonKey(name: r'enabled_toolsets', required: false, includeIfNull: false)
  final List<String>? enabledToolsets;

  @JsonKey(name: r'workdir', required: false, includeIfNull: false)
  final String? workdir;

  @JsonKey(
    defaultValue: false,
    name: r'no_agent',
    required: false,
    includeIfNull: false,
  )
  final bool? noAgent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CronJobCreate &&
          other.paused == paused &&
          other.pausedReason == pausedReason &&
          other.prompt == prompt &&
          other.schedule == schedule &&
          other.name == name &&
          other.deliver == deliver &&
          other.skills == skills &&
          other.model == model &&
          other.provider == provider &&
          other.baseUrl == baseUrl &&
          other.script == script &&
          other.contextFrom == contextFrom &&
          other.enabledToolsets == enabledToolsets &&
          other.workdir == workdir &&
          other.noAgent == noAgent;

  @override
  int get hashCode =>
      paused.hashCode +
      (pausedReason == null ? 0 : pausedReason.hashCode) +
      prompt.hashCode +
      schedule.hashCode +
      name.hashCode +
      deliver.hashCode +
      (skills == null ? 0 : skills.hashCode) +
      (model == null ? 0 : model.hashCode) +
      (provider == null ? 0 : provider.hashCode) +
      (baseUrl == null ? 0 : baseUrl.hashCode) +
      (script == null ? 0 : script.hashCode) +
      (contextFrom == null ? 0 : contextFrom.hashCode) +
      (enabledToolsets == null ? 0 : enabledToolsets.hashCode) +
      (workdir == null ? 0 : workdir.hashCode) +
      noAgent.hashCode;

  factory CronJobCreate.fromJson(Map<String, dynamic> json) =>
      _$CronJobCreateFromJson(json);

  Map<String, dynamic> toJson() => _$CronJobCreateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
