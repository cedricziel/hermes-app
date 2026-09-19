//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'model_assignment.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ModelAssignment {
  /// Returns a new [ModelAssignment] instance.
  ModelAssignment({
    required this.scope,

    required this.provider,

    required this.model,

    this.task = '',

    this.reasoningEffort,

    this.baseUrl = '',

    this.apiKey = '',

    this.confirmExpensiveModel = false,

    this.profile,
  });

  @JsonKey(name: r'scope', required: true, includeIfNull: false)
  final String scope;

  @JsonKey(name: r'provider', required: true, includeIfNull: false)
  final String provider;

  @JsonKey(name: r'model', required: true, includeIfNull: false)
  final String model;

  @JsonKey(
    defaultValue: '',
    name: r'task',
    required: false,
    includeIfNull: false,
  )
  final String? task;

  @JsonKey(name: r'reasoning_effort', required: false, includeIfNull: false)
  final String? reasoningEffort;

  @JsonKey(
    defaultValue: '',
    name: r'base_url',
    required: false,
    includeIfNull: false,
  )
  final String? baseUrl;

  @JsonKey(
    defaultValue: '',
    name: r'api_key',
    required: false,
    includeIfNull: false,
  )
  final String? apiKey;

  @JsonKey(
    defaultValue: false,
    name: r'confirm_expensive_model',
    required: false,
    includeIfNull: false,
  )
  final bool? confirmExpensiveModel;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModelAssignment &&
          other.scope == scope &&
          other.provider == provider &&
          other.model == model &&
          other.task == task &&
          other.reasoningEffort == reasoningEffort &&
          other.baseUrl == baseUrl &&
          other.apiKey == apiKey &&
          other.confirmExpensiveModel == confirmExpensiveModel &&
          other.profile == profile;

  @override
  int get hashCode =>
      scope.hashCode +
      provider.hashCode +
      model.hashCode +
      task.hashCode +
      (reasoningEffort == null ? 0 : reasoningEffort.hashCode) +
      baseUrl.hashCode +
      apiKey.hashCode +
      confirmExpensiveModel.hashCode +
      (profile == null ? 0 : profile.hashCode);

  factory ModelAssignment.fromJson(Map<String, dynamic> json) =>
      _$ModelAssignmentFromJson(json);

  Map<String, dynamic> toJson() => _$ModelAssignmentToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
