//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_prune.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionPrune {
  /// Returns a new [SessionPrune] instance.
  SessionPrune({
    this.olderThanDays,

    this.source_,

    this.profile,

    this.startedBefore,

    this.startedAfter,

    this.titleLike,

    this.endReason,

    this.cwdPrefix,

    this.minMessages,

    this.maxMessages,

    this.modelLike,

    this.provider,

    this.userId,

    this.chatId,

    this.chatType,

    this.branchLike,

    this.minTokens,

    this.maxTokens,

    this.minCost,

    this.maxCost,

    this.minToolCalls,

    this.maxToolCalls,

    this.includeArchived = false,

    this.dryRun = false,
  });

  @JsonKey(name: r'older_than_days', required: false, includeIfNull: false)
  final num? olderThanDays;

  @JsonKey(name: r'source', required: false, includeIfNull: false)
  final String? source_;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @JsonKey(name: r'started_before', required: false, includeIfNull: false)
  final num? startedBefore;

  @JsonKey(name: r'started_after', required: false, includeIfNull: false)
  final num? startedAfter;

  @JsonKey(name: r'title_like', required: false, includeIfNull: false)
  final String? titleLike;

  @JsonKey(name: r'end_reason', required: false, includeIfNull: false)
  final String? endReason;

  @JsonKey(name: r'cwd_prefix', required: false, includeIfNull: false)
  final String? cwdPrefix;

  @JsonKey(name: r'min_messages', required: false, includeIfNull: false)
  final int? minMessages;

  @JsonKey(name: r'max_messages', required: false, includeIfNull: false)
  final int? maxMessages;

  @JsonKey(name: r'model_like', required: false, includeIfNull: false)
  final String? modelLike;

  @JsonKey(name: r'provider', required: false, includeIfNull: false)
  final String? provider;

  @JsonKey(name: r'user_id', required: false, includeIfNull: false)
  final String? userId;

  @JsonKey(name: r'chat_id', required: false, includeIfNull: false)
  final String? chatId;

  @JsonKey(name: r'chat_type', required: false, includeIfNull: false)
  final String? chatType;

  @JsonKey(name: r'branch_like', required: false, includeIfNull: false)
  final String? branchLike;

  @JsonKey(name: r'min_tokens', required: false, includeIfNull: false)
  final int? minTokens;

  @JsonKey(name: r'max_tokens', required: false, includeIfNull: false)
  final int? maxTokens;

  @JsonKey(name: r'min_cost', required: false, includeIfNull: false)
  final num? minCost;

  @JsonKey(name: r'max_cost', required: false, includeIfNull: false)
  final num? maxCost;

  @JsonKey(name: r'min_tool_calls', required: false, includeIfNull: false)
  final int? minToolCalls;

  @JsonKey(name: r'max_tool_calls', required: false, includeIfNull: false)
  final int? maxToolCalls;

  @JsonKey(
    defaultValue: false,
    name: r'include_archived',
    required: false,
    includeIfNull: false,
  )
  final bool? includeArchived;

  @JsonKey(
    defaultValue: false,
    name: r'dry_run',
    required: false,
    includeIfNull: false,
  )
  final bool? dryRun;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionPrune &&
          other.olderThanDays == olderThanDays &&
          other.source_ == source_ &&
          other.profile == profile &&
          other.startedBefore == startedBefore &&
          other.startedAfter == startedAfter &&
          other.titleLike == titleLike &&
          other.endReason == endReason &&
          other.cwdPrefix == cwdPrefix &&
          other.minMessages == minMessages &&
          other.maxMessages == maxMessages &&
          other.modelLike == modelLike &&
          other.provider == provider &&
          other.userId == userId &&
          other.chatId == chatId &&
          other.chatType == chatType &&
          other.branchLike == branchLike &&
          other.minTokens == minTokens &&
          other.maxTokens == maxTokens &&
          other.minCost == minCost &&
          other.maxCost == maxCost &&
          other.minToolCalls == minToolCalls &&
          other.maxToolCalls == maxToolCalls &&
          other.includeArchived == includeArchived &&
          other.dryRun == dryRun;

  @override
  int get hashCode =>
      (olderThanDays == null ? 0 : olderThanDays.hashCode) +
      (source_ == null ? 0 : source_.hashCode) +
      (profile == null ? 0 : profile.hashCode) +
      (startedBefore == null ? 0 : startedBefore.hashCode) +
      (startedAfter == null ? 0 : startedAfter.hashCode) +
      (titleLike == null ? 0 : titleLike.hashCode) +
      (endReason == null ? 0 : endReason.hashCode) +
      (cwdPrefix == null ? 0 : cwdPrefix.hashCode) +
      (minMessages == null ? 0 : minMessages.hashCode) +
      (maxMessages == null ? 0 : maxMessages.hashCode) +
      (modelLike == null ? 0 : modelLike.hashCode) +
      (provider == null ? 0 : provider.hashCode) +
      (userId == null ? 0 : userId.hashCode) +
      (chatId == null ? 0 : chatId.hashCode) +
      (chatType == null ? 0 : chatType.hashCode) +
      (branchLike == null ? 0 : branchLike.hashCode) +
      (minTokens == null ? 0 : minTokens.hashCode) +
      (maxTokens == null ? 0 : maxTokens.hashCode) +
      (minCost == null ? 0 : minCost.hashCode) +
      (maxCost == null ? 0 : maxCost.hashCode) +
      (minToolCalls == null ? 0 : minToolCalls.hashCode) +
      (maxToolCalls == null ? 0 : maxToolCalls.hashCode) +
      includeArchived.hashCode +
      dryRun.hashCode;

  factory SessionPrune.fromJson(Map<String, dynamic> json) =>
      _$SessionPruneFromJson(json);

  Map<String, dynamic> toJson() => _$SessionPruneToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
