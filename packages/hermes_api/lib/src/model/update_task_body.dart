//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'update_task_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class UpdateTaskBody {
  /// Returns a new [UpdateTaskBody] instance.
  UpdateTaskBody({
    this.status,

    this.assignee,

    this.priority,

    this.title,

    this.body,

    this.result,

    this.blockReason,

    this.summary,

    this.metadata,

    this.modelOverride,

    this.providerOverride,

    this.clearModelOverride = false,

    this.reasoningEffort,

    this.clearReasoningEffort = false,
  });

  @JsonKey(name: r'status', required: false, includeIfNull: false)
  final String? status;

  @JsonKey(name: r'assignee', required: false, includeIfNull: false)
  final String? assignee;

  @JsonKey(name: r'priority', required: false, includeIfNull: false)
  final int? priority;

  @JsonKey(name: r'title', required: false, includeIfNull: false)
  final String? title;

  @JsonKey(name: r'body', required: false, includeIfNull: false)
  final String? body;

  @JsonKey(name: r'result', required: false, includeIfNull: false)
  final String? result;

  @JsonKey(name: r'block_reason', required: false, includeIfNull: false)
  final String? blockReason;

  @JsonKey(name: r'summary', required: false, includeIfNull: false)
  final String? summary;

  @JsonKey(name: r'metadata', required: false, includeIfNull: false)
  final Map<String, Object>? metadata;

  @JsonKey(name: r'model_override', required: false, includeIfNull: false)
  final String? modelOverride;

  @JsonKey(name: r'provider_override', required: false, includeIfNull: false)
  final String? providerOverride;

  @JsonKey(
    defaultValue: false,
    name: r'clear_model_override',
    required: false,
    includeIfNull: false,
  )
  final bool? clearModelOverride;

  @JsonKey(name: r'reasoning_effort', required: false, includeIfNull: false)
  final String? reasoningEffort;

  @JsonKey(
    defaultValue: false,
    name: r'clear_reasoning_effort',
    required: false,
    includeIfNull: false,
  )
  final bool? clearReasoningEffort;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UpdateTaskBody &&
          other.status == status &&
          other.assignee == assignee &&
          other.priority == priority &&
          other.title == title &&
          other.body == body &&
          other.result == result &&
          other.blockReason == blockReason &&
          other.summary == summary &&
          other.metadata == metadata &&
          other.modelOverride == modelOverride &&
          other.providerOverride == providerOverride &&
          other.clearModelOverride == clearModelOverride &&
          other.reasoningEffort == reasoningEffort &&
          other.clearReasoningEffort == clearReasoningEffort;

  @override
  int get hashCode =>
      (status == null ? 0 : status.hashCode) +
      (assignee == null ? 0 : assignee.hashCode) +
      (priority == null ? 0 : priority.hashCode) +
      (title == null ? 0 : title.hashCode) +
      (body == null ? 0 : body.hashCode) +
      (result == null ? 0 : result.hashCode) +
      (blockReason == null ? 0 : blockReason.hashCode) +
      (summary == null ? 0 : summary.hashCode) +
      (metadata == null ? 0 : metadata.hashCode) +
      (modelOverride == null ? 0 : modelOverride.hashCode) +
      (providerOverride == null ? 0 : providerOverride.hashCode) +
      clearModelOverride.hashCode +
      (reasoningEffort == null ? 0 : reasoningEffort.hashCode) +
      clearReasoningEffort.hashCode;

  factory UpdateTaskBody.fromJson(Map<String, dynamic> json) =>
      _$UpdateTaskBodyFromJson(json);

  Map<String, dynamic> toJson() => _$UpdateTaskBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
