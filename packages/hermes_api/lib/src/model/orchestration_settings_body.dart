//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'orchestration_settings_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrchestrationSettingsBody {
  /// Returns a new [OrchestrationSettingsBody] instance.
  OrchestrationSettingsBody({
    this.orchestratorProfile,

    this.defaultAssignee,

    this.autoDecompose,

    this.autoPromoteChildren,
  });

  @JsonKey(name: r'orchestrator_profile', required: false, includeIfNull: false)
  final String? orchestratorProfile;

  @JsonKey(name: r'default_assignee', required: false, includeIfNull: false)
  final String? defaultAssignee;

  @JsonKey(name: r'auto_decompose', required: false, includeIfNull: false)
  final bool? autoDecompose;

  @JsonKey(
    name: r'auto_promote_children',
    required: false,
    includeIfNull: false,
  )
  final bool? autoPromoteChildren;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrchestrationSettingsBody &&
          other.orchestratorProfile == orchestratorProfile &&
          other.defaultAssignee == defaultAssignee &&
          other.autoDecompose == autoDecompose &&
          other.autoPromoteChildren == autoPromoteChildren;

  @override
  int get hashCode =>
      (orchestratorProfile == null ? 0 : orchestratorProfile.hashCode) +
      (defaultAssignee == null ? 0 : defaultAssignee.hashCode) +
      (autoDecompose == null ? 0 : autoDecompose.hashCode) +
      (autoPromoteChildren == null ? 0 : autoPromoteChildren.hashCode);

  factory OrchestrationSettingsBody.fromJson(Map<String, dynamic> json) =>
      _$OrchestrationSettingsBodyFromJson(json);

  Map<String, dynamic> toJson() => _$OrchestrationSettingsBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
