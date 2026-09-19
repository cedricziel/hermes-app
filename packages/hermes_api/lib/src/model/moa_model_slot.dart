//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'moa_model_slot.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MoaModelSlot {
  /// Returns a new [MoaModelSlot] instance.
  MoaModelSlot({
    this.provider = '',

    this.model = '',

    this.reasoningEffort,

    this.enabled = true,
  });

  @JsonKey(
    defaultValue: '',
    name: r'provider',
    required: false,
    includeIfNull: false,
  )
  final String? provider;

  @JsonKey(
    defaultValue: '',
    name: r'model',
    required: false,
    includeIfNull: false,
  )
  final String? model;

  @JsonKey(name: r'reasoning_effort', required: false, includeIfNull: false)
  final String? reasoningEffort;

  @JsonKey(
    defaultValue: true,
    name: r'enabled',
    required: false,
    includeIfNull: false,
  )
  final bool? enabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoaModelSlot &&
          other.provider == provider &&
          other.model == model &&
          other.reasoningEffort == reasoningEffort &&
          other.enabled == enabled;

  @override
  int get hashCode =>
      provider.hashCode +
      model.hashCode +
      (reasoningEffort == null ? 0 : reasoningEffort.hashCode) +
      enabled.hashCode;

  factory MoaModelSlot.fromJson(Map<String, dynamic> json) =>
      _$MoaModelSlotFromJson(json);

  Map<String, dynamic> toJson() => _$MoaModelSlotToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
