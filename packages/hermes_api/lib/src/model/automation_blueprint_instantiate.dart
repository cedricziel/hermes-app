//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'automation_blueprint_instantiate.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AutomationBlueprintInstantiate {
  /// Returns a new [AutomationBlueprintInstantiate] instance.
  AutomationBlueprintInstantiate({
    required this.blueprint,

    this.values = const {},
  });

  @JsonKey(name: r'blueprint', required: true, includeIfNull: false)
  final String blueprint;

  @JsonKey(
    defaultValue: {},
    name: r'values',
    required: false,
    includeIfNull: false,
  )
  final Map<String, Object>? values;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AutomationBlueprintInstantiate &&
          other.blueprint == blueprint &&
          other.values == values;

  @override
  int get hashCode => blueprint.hashCode + values.hashCode;

  factory AutomationBlueprintInstantiate.fromJson(Map<String, dynamic> json) =>
      _$AutomationBlueprintInstantiateFromJson(json);

  Map<String, dynamic> toJson() => _$AutomationBlueprintInstantiateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
