// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_task_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateTaskBodyCWProxy {
  CreateTaskBody title(String title);

  CreateTaskBody body(String? body);

  CreateTaskBody assignee(String? assignee);

  CreateTaskBody tenant(String? tenant);

  CreateTaskBody priority(int? priority);

  CreateTaskBody workspaceKind(String? workspaceKind);

  CreateTaskBody workspacePath(String? workspacePath);

  CreateTaskBody parents(List<String>? parents);

  CreateTaskBody triage(bool? triage);

  CreateTaskBody idempotencyKey(String? idempotencyKey);

  CreateTaskBody maxRuntimeSeconds(int? maxRuntimeSeconds);

  CreateTaskBody skills(List<String>? skills);

  CreateTaskBody goalMode(bool? goalMode);

  CreateTaskBody goalMaxTurns(int? goalMaxTurns);

  CreateTaskBody modelOverride(String? modelOverride);

  CreateTaskBody providerOverride(String? providerOverride);

  CreateTaskBody reasoningEffort(String? reasoningEffort);

  CreateTaskBody projectId(String? projectId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CreateTaskBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CreateTaskBody(...).copyWith(id: 12, name: "My name")
  /// ```
  CreateTaskBody call({
    String title,
    String? body,
    String? assignee,
    String? tenant,
    int? priority,
    String? workspaceKind,
    String? workspacePath,
    List<String>? parents,
    bool? triage,
    String? idempotencyKey,
    int? maxRuntimeSeconds,
    List<String>? skills,
    bool? goalMode,
    int? goalMaxTurns,
    String? modelOverride,
    String? providerOverride,
    String? reasoningEffort,
    String? projectId,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCreateTaskBody.copyWith(...)` or call `instanceOfCreateTaskBody.copyWith.fieldName(value)` for a single field.
class _$CreateTaskBodyCWProxyImpl implements _$CreateTaskBodyCWProxy {
  const _$CreateTaskBodyCWProxyImpl(this._value);

  final CreateTaskBody _value;

  @override
  CreateTaskBody title(String title) => call(title: title);

  @override
  CreateTaskBody body(String? body) => call(body: body);

  @override
  CreateTaskBody assignee(String? assignee) => call(assignee: assignee);

  @override
  CreateTaskBody tenant(String? tenant) => call(tenant: tenant);

  @override
  CreateTaskBody priority(int? priority) => call(priority: priority);

  @override
  CreateTaskBody workspaceKind(String? workspaceKind) =>
      call(workspaceKind: workspaceKind);

  @override
  CreateTaskBody workspacePath(String? workspacePath) =>
      call(workspacePath: workspacePath);

  @override
  CreateTaskBody parents(List<String>? parents) => call(parents: parents);

  @override
  CreateTaskBody triage(bool? triage) => call(triage: triage);

  @override
  CreateTaskBody idempotencyKey(String? idempotencyKey) =>
      call(idempotencyKey: idempotencyKey);

  @override
  CreateTaskBody maxRuntimeSeconds(int? maxRuntimeSeconds) =>
      call(maxRuntimeSeconds: maxRuntimeSeconds);

  @override
  CreateTaskBody skills(List<String>? skills) => call(skills: skills);

  @override
  CreateTaskBody goalMode(bool? goalMode) => call(goalMode: goalMode);

  @override
  CreateTaskBody goalMaxTurns(int? goalMaxTurns) =>
      call(goalMaxTurns: goalMaxTurns);

  @override
  CreateTaskBody modelOverride(String? modelOverride) =>
      call(modelOverride: modelOverride);

  @override
  CreateTaskBody providerOverride(String? providerOverride) =>
      call(providerOverride: providerOverride);

  @override
  CreateTaskBody reasoningEffort(String? reasoningEffort) =>
      call(reasoningEffort: reasoningEffort);

  @override
  CreateTaskBody projectId(String? projectId) => call(projectId: projectId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CreateTaskBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CreateTaskBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  CreateTaskBody call({
    Object? title = const $CopyWithPlaceholder(),
    Object? body = const $CopyWithPlaceholder(),
    Object? assignee = const $CopyWithPlaceholder(),
    Object? tenant = const $CopyWithPlaceholder(),
    Object? priority = const $CopyWithPlaceholder(),
    Object? workspaceKind = const $CopyWithPlaceholder(),
    Object? workspacePath = const $CopyWithPlaceholder(),
    Object? parents = const $CopyWithPlaceholder(),
    Object? triage = const $CopyWithPlaceholder(),
    Object? idempotencyKey = const $CopyWithPlaceholder(),
    Object? maxRuntimeSeconds = const $CopyWithPlaceholder(),
    Object? skills = const $CopyWithPlaceholder(),
    Object? goalMode = const $CopyWithPlaceholder(),
    Object? goalMaxTurns = const $CopyWithPlaceholder(),
    Object? modelOverride = const $CopyWithPlaceholder(),
    Object? providerOverride = const $CopyWithPlaceholder(),
    Object? reasoningEffort = const $CopyWithPlaceholder(),
    Object? projectId = const $CopyWithPlaceholder(),
  }) {
    return CreateTaskBody(
      title: title == const $CopyWithPlaceholder() || title == null
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String,
      body: body == const $CopyWithPlaceholder()
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String?,
      assignee: assignee == const $CopyWithPlaceholder()
          ? _value.assignee
          // ignore: cast_nullable_to_non_nullable
          : assignee as String?,
      tenant: tenant == const $CopyWithPlaceholder()
          ? _value.tenant
          // ignore: cast_nullable_to_non_nullable
          : tenant as String?,
      priority: priority == const $CopyWithPlaceholder()
          ? _value.priority
          // ignore: cast_nullable_to_non_nullable
          : priority as int?,
      workspaceKind: workspaceKind == const $CopyWithPlaceholder()
          ? _value.workspaceKind
          // ignore: cast_nullable_to_non_nullable
          : workspaceKind as String?,
      workspacePath: workspacePath == const $CopyWithPlaceholder()
          ? _value.workspacePath
          // ignore: cast_nullable_to_non_nullable
          : workspacePath as String?,
      parents: parents == const $CopyWithPlaceholder()
          ? _value.parents
          // ignore: cast_nullable_to_non_nullable
          : parents as List<String>?,
      triage: triage == const $CopyWithPlaceholder()
          ? _value.triage
          // ignore: cast_nullable_to_non_nullable
          : triage as bool?,
      idempotencyKey: idempotencyKey == const $CopyWithPlaceholder()
          ? _value.idempotencyKey
          // ignore: cast_nullable_to_non_nullable
          : idempotencyKey as String?,
      maxRuntimeSeconds: maxRuntimeSeconds == const $CopyWithPlaceholder()
          ? _value.maxRuntimeSeconds
          // ignore: cast_nullable_to_non_nullable
          : maxRuntimeSeconds as int?,
      skills: skills == const $CopyWithPlaceholder()
          ? _value.skills
          // ignore: cast_nullable_to_non_nullable
          : skills as List<String>?,
      goalMode: goalMode == const $CopyWithPlaceholder()
          ? _value.goalMode
          // ignore: cast_nullable_to_non_nullable
          : goalMode as bool?,
      goalMaxTurns: goalMaxTurns == const $CopyWithPlaceholder()
          ? _value.goalMaxTurns
          // ignore: cast_nullable_to_non_nullable
          : goalMaxTurns as int?,
      modelOverride: modelOverride == const $CopyWithPlaceholder()
          ? _value.modelOverride
          // ignore: cast_nullable_to_non_nullable
          : modelOverride as String?,
      providerOverride: providerOverride == const $CopyWithPlaceholder()
          ? _value.providerOverride
          // ignore: cast_nullable_to_non_nullable
          : providerOverride as String?,
      reasoningEffort: reasoningEffort == const $CopyWithPlaceholder()
          ? _value.reasoningEffort
          // ignore: cast_nullable_to_non_nullable
          : reasoningEffort as String?,
      projectId: projectId == const $CopyWithPlaceholder()
          ? _value.projectId
          // ignore: cast_nullable_to_non_nullable
          : projectId as String?,
    );
  }
}

extension $CreateTaskBodyCopyWith on CreateTaskBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCreateTaskBody.copyWith(...)` or `instanceOfCreateTaskBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateTaskBodyCWProxy get copyWith => _$CreateTaskBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateTaskBody _$CreateTaskBodyFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CreateTaskBody',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['title']);
    final val = CreateTaskBody(
      title: $checkedConvert('title', (v) => v as String),
      body: $checkedConvert('body', (v) => v as String?),
      assignee: $checkedConvert('assignee', (v) => v as String?),
      tenant: $checkedConvert('tenant', (v) => v as String?),
      priority: $checkedConvert('priority', (v) => (v as num?)?.toInt() ?? 0),
      workspaceKind: $checkedConvert('workspace_kind', (v) => v as String?),
      workspacePath: $checkedConvert('workspace_path', (v) => v as String?),
      parents: $checkedConvert(
        'parents',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
      ),
      triage: $checkedConvert('triage', (v) => v as bool? ?? false),
      idempotencyKey: $checkedConvert('idempotency_key', (v) => v as String?),
      maxRuntimeSeconds: $checkedConvert(
        'max_runtime_seconds',
        (v) => (v as num?)?.toInt(),
      ),
      skills: $checkedConvert(
        'skills',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
      ),
      goalMode: $checkedConvert('goal_mode', (v) => v as bool? ?? false),
      goalMaxTurns: $checkedConvert(
        'goal_max_turns',
        (v) => (v as num?)?.toInt(),
      ),
      modelOverride: $checkedConvert('model_override', (v) => v as String?),
      providerOverride: $checkedConvert(
        'provider_override',
        (v) => v as String?,
      ),
      reasoningEffort: $checkedConvert('reasoning_effort', (v) => v as String?),
      projectId: $checkedConvert('project_id', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'workspaceKind': 'workspace_kind',
    'workspacePath': 'workspace_path',
    'idempotencyKey': 'idempotency_key',
    'maxRuntimeSeconds': 'max_runtime_seconds',
    'goalMode': 'goal_mode',
    'goalMaxTurns': 'goal_max_turns',
    'modelOverride': 'model_override',
    'providerOverride': 'provider_override',
    'reasoningEffort': 'reasoning_effort',
    'projectId': 'project_id',
  },
);

Map<String, dynamic> _$CreateTaskBodyToJson(CreateTaskBody instance) =>
    <String, dynamic>{
      'title': instance.title,
      'body': ?instance.body,
      'assignee': ?instance.assignee,
      'tenant': ?instance.tenant,
      'priority': ?instance.priority,
      'workspace_kind': ?instance.workspaceKind,
      'workspace_path': ?instance.workspacePath,
      'parents': ?instance.parents,
      'triage': ?instance.triage,
      'idempotency_key': ?instance.idempotencyKey,
      'max_runtime_seconds': ?instance.maxRuntimeSeconds,
      'skills': ?instance.skills,
      'goal_mode': ?instance.goalMode,
      'goal_max_turns': ?instance.goalMaxTurns,
      'model_override': ?instance.modelOverride,
      'provider_override': ?instance.providerOverride,
      'reasoning_effort': ?instance.reasoningEffort,
      'project_id': ?instance.projectId,
    };
