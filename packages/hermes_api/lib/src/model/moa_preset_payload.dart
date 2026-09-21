//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

import 'package:copy_with_extension/copy_with_extension.dart';
// ignore_for_file: unused_element
import 'package:hermes_api/src/model/moa_model_slot.dart';
import 'package:json_annotation/json_annotation.dart';

part 'moa_preset_payload.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MoaPresetPayload {
  /// Returns a new [MoaPresetPayload] instance.
  MoaPresetPayload({
    this.referenceTimeout,

    this.degradedReferencePolicy =
        MoaPresetPayloadDegradedReferencePolicyEnum.loud,

    this.referenceModels = const [],

    this.aggregator,

    this.referenceTemperature,

    this.aggregatorTemperature,

    this.fanout,

    this.enabled = true,
  });

  @JsonKey(name: r'reference_timeout', required: false, includeIfNull: false)
  final num? referenceTimeout;

  @JsonKey(
    defaultValue: MoaPresetPayloadDegradedReferencePolicyEnum.loud,
    name: r'degraded_reference_policy',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        MoaPresetPayloadDegradedReferencePolicyEnum.unknownDefaultOpenApi,
  )
  final MoaPresetPayloadDegradedReferencePolicyEnum? degradedReferencePolicy;

  @JsonKey(
    defaultValue: [],
    name: r'reference_models',
    required: false,
    includeIfNull: false,
  )
  final List<MoaModelSlot>? referenceModels;

  @JsonKey(name: r'aggregator', required: false, includeIfNull: false)
  final MoaModelSlot? aggregator;

  @JsonKey(
    name: r'reference_temperature',
    required: false,
    includeIfNull: false,
  )
  final num? referenceTemperature;

  @JsonKey(
    name: r'aggregator_temperature',
    required: false,
    includeIfNull: false,
  )
  final num? aggregatorTemperature;

  @JsonKey(name: r'fanout', required: false, includeIfNull: false)
  final String? fanout;

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
      other is MoaPresetPayload &&
          other.referenceTimeout == referenceTimeout &&
          other.degradedReferencePolicy == degradedReferencePolicy &&
          other.referenceModels == referenceModels &&
          other.aggregator == aggregator &&
          other.referenceTemperature == referenceTemperature &&
          other.aggregatorTemperature == aggregatorTemperature &&
          other.fanout == fanout &&
          other.enabled == enabled;

  @override
  int get hashCode =>
      (referenceTimeout == null ? 0 : referenceTimeout.hashCode) +
      degradedReferencePolicy.hashCode +
      referenceModels.hashCode +
      aggregator.hashCode +
      (referenceTemperature == null ? 0 : referenceTemperature.hashCode) +
      (aggregatorTemperature == null ? 0 : aggregatorTemperature.hashCode) +
      (fanout == null ? 0 : fanout.hashCode) +
      enabled.hashCode;

  factory MoaPresetPayload.fromJson(Map<String, dynamic> json) =>
      _$MoaPresetPayloadFromJson(json);

  Map<String, dynamic> toJson() => _$MoaPresetPayloadToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum MoaPresetPayloadDegradedReferencePolicyEnum {
  @JsonValue(r'loud')
  loud(r'loud'),
  @JsonValue(r'silent')
  silent(r'silent'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const MoaPresetPayloadDegradedReferencePolicyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
