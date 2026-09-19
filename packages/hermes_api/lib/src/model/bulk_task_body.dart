//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bulk_task_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BulkTaskBody {
  /// Returns a new [BulkTaskBody] instance.
  BulkTaskBody({
    required this.ids,

    this.status,

    this.assignee,

    this.priority,

    this.archive = false,

    this.result,

    this.summary,

    this.metadata,

    this.reclaimFirst = false,

    this.modelOverride,

    this.providerOverride,

    this.clearModelOverride = false,

    this.reasoningEffort,

    this.clearReasoningEffort = false,
  });

  @JsonKey(name: r'ids', required: true, includeIfNull: false)
  final List<String> ids;

  @JsonKey(name: r'status', required: false, includeIfNull: false)
  final String? status;

  @JsonKey(name: r'assignee', required: false, includeIfNull: false)
  final String? assignee;

  @JsonKey(name: r'priority', required: false, includeIfNull: false)
  final int? priority;

  @JsonKey(
    defaultValue: false,
    name: r'archive',
    required: false,
    includeIfNull: false,
  )
  final bool? archive;

  @JsonKey(name: r'result', required: false, includeIfNull: false)
  final String? result;

  @JsonKey(name: r'summary', required: false, includeIfNull: false)
  final String? summary;

  @JsonKey(name: r'metadata', required: false, includeIfNull: false)
  final Map<String, Object>? metadata;

  @JsonKey(
    defaultValue: false,
    name: r'reclaim_first',
    required: false,
    includeIfNull: false,
  )
  final bool? reclaimFirst;

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
      other is BulkTaskBody &&
          other.ids == ids &&
          other.status == status &&
          other.assignee == assignee &&
          other.priority == priority &&
          other.archive == archive &&
          other.result == result &&
          other.summary == summary &&
          other.metadata == metadata &&
          other.reclaimFirst == reclaimFirst &&
          other.modelOverride == modelOverride &&
          other.providerOverride == providerOverride &&
          other.clearModelOverride == clearModelOverride &&
          other.reasoningEffort == reasoningEffort &&
          other.clearReasoningEffort == clearReasoningEffort;

  @override
  int get hashCode =>
      ids.hashCode +
      (status == null ? 0 : status.hashCode) +
      (assignee == null ? 0 : assignee.hashCode) +
      (priority == null ? 0 : priority.hashCode) +
      archive.hashCode +
      (result == null ? 0 : result.hashCode) +
      (summary == null ? 0 : summary.hashCode) +
      (metadata == null ? 0 : metadata.hashCode) +
      reclaimFirst.hashCode +
      (modelOverride == null ? 0 : modelOverride.hashCode) +
      (providerOverride == null ? 0 : providerOverride.hashCode) +
      clearModelOverride.hashCode +
      (reasoningEffort == null ? 0 : reasoningEffort.hashCode) +
      clearReasoningEffort.hashCode;

  factory BulkTaskBody.fromJson(Map<String, dynamic> json) =>
      _$BulkTaskBodyFromJson(json);

  Map<String, dynamic> toJson() => _$BulkTaskBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
