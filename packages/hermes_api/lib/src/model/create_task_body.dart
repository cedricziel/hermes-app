//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'create_task_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CreateTaskBody {
  /// Returns a new [CreateTaskBody] instance.
  CreateTaskBody({
    required this.title,

    this.body,

    this.assignee,

    this.tenant,

    this.priority = 0,

    this.workspaceKind,

    this.workspacePath,

    this.parents,

    this.triage = false,

    this.idempotencyKey,

    this.maxRuntimeSeconds,

    this.skills,

    this.goalMode = false,

    this.goalMaxTurns,

    this.modelOverride,

    this.providerOverride,

    this.reasoningEffort,

    this.projectId,
  });

  @JsonKey(name: r'title', required: true, includeIfNull: false)
  final String title;

  @JsonKey(name: r'body', required: false, includeIfNull: false)
  final String? body;

  @JsonKey(name: r'assignee', required: false, includeIfNull: false)
  final String? assignee;

  @JsonKey(name: r'tenant', required: false, includeIfNull: false)
  final String? tenant;

  @JsonKey(
    defaultValue: 0,
    name: r'priority',
    required: false,
    includeIfNull: false,
  )
  final int? priority;

  @JsonKey(name: r'workspace_kind', required: false, includeIfNull: false)
  final String? workspaceKind;

  @JsonKey(name: r'workspace_path', required: false, includeIfNull: false)
  final String? workspacePath;

  @JsonKey(name: r'parents', required: false, includeIfNull: false)
  final List<String>? parents;

  @JsonKey(
    defaultValue: false,
    name: r'triage',
    required: false,
    includeIfNull: false,
  )
  final bool? triage;

  @JsonKey(name: r'idempotency_key', required: false, includeIfNull: false)
  final String? idempotencyKey;

  @JsonKey(name: r'max_runtime_seconds', required: false, includeIfNull: false)
  final int? maxRuntimeSeconds;

  @JsonKey(name: r'skills', required: false, includeIfNull: false)
  final List<String>? skills;

  @JsonKey(
    defaultValue: false,
    name: r'goal_mode',
    required: false,
    includeIfNull: false,
  )
  final bool? goalMode;

  @JsonKey(name: r'goal_max_turns', required: false, includeIfNull: false)
  final int? goalMaxTurns;

  @JsonKey(name: r'model_override', required: false, includeIfNull: false)
  final String? modelOverride;

  @JsonKey(name: r'provider_override', required: false, includeIfNull: false)
  final String? providerOverride;

  @JsonKey(name: r'reasoning_effort', required: false, includeIfNull: false)
  final String? reasoningEffort;

  @JsonKey(name: r'project_id', required: false, includeIfNull: false)
  final String? projectId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CreateTaskBody &&
          other.title == title &&
          other.body == body &&
          other.assignee == assignee &&
          other.tenant == tenant &&
          other.priority == priority &&
          other.workspaceKind == workspaceKind &&
          other.workspacePath == workspacePath &&
          other.parents == parents &&
          other.triage == triage &&
          other.idempotencyKey == idempotencyKey &&
          other.maxRuntimeSeconds == maxRuntimeSeconds &&
          other.skills == skills &&
          other.goalMode == goalMode &&
          other.goalMaxTurns == goalMaxTurns &&
          other.modelOverride == modelOverride &&
          other.providerOverride == providerOverride &&
          other.reasoningEffort == reasoningEffort &&
          other.projectId == projectId;

  @override
  int get hashCode =>
      title.hashCode +
      (body == null ? 0 : body.hashCode) +
      (assignee == null ? 0 : assignee.hashCode) +
      (tenant == null ? 0 : tenant.hashCode) +
      priority.hashCode +
      (workspaceKind == null ? 0 : workspaceKind.hashCode) +
      (workspacePath == null ? 0 : workspacePath.hashCode) +
      parents.hashCode +
      triage.hashCode +
      (idempotencyKey == null ? 0 : idempotencyKey.hashCode) +
      (maxRuntimeSeconds == null ? 0 : maxRuntimeSeconds.hashCode) +
      (skills == null ? 0 : skills.hashCode) +
      goalMode.hashCode +
      (goalMaxTurns == null ? 0 : goalMaxTurns.hashCode) +
      (modelOverride == null ? 0 : modelOverride.hashCode) +
      (providerOverride == null ? 0 : providerOverride.hashCode) +
      (reasoningEffort == null ? 0 : reasoningEffort.hashCode) +
      (projectId == null ? 0 : projectId.hashCode);

  factory CreateTaskBody.fromJson(Map<String, dynamic> json) =>
      _$CreateTaskBodyFromJson(json);

  Map<String, dynamic> toJson() => _$CreateTaskBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
