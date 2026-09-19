//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:hermes_api/src/model/moa_model_slot.dart';
import 'package:hermes_api/src/model/moa_preset_payload.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'moa_config_payload.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MoaConfigPayload {
  /// Returns a new [MoaConfigPayload] instance.
  MoaConfigPayload({
    this.referenceTimeout,

    this.degradedReferencePolicy =
        MoaConfigPayloadDegradedReferencePolicyEnum.loud,

    this.defaultPreset = 'default',

    this.activePreset = '',

    this.presets = const {},

    this.referenceModels = const [],

    this.aggregator,

    this.referenceTemperature,

    this.aggregatorTemperature,

    this.fanout,

    this.enabled = true,

    this.profile,
  });

  @JsonKey(name: r'reference_timeout', required: false, includeIfNull: false)
  final num? referenceTimeout;

  @JsonKey(
    defaultValue: MoaConfigPayloadDegradedReferencePolicyEnum.loud,
    name: r'degraded_reference_policy',
    required: false,
    includeIfNull: false,
    unknownEnumValue:
        MoaConfigPayloadDegradedReferencePolicyEnum.unknownDefaultOpenApi,
  )
  final MoaConfigPayloadDegradedReferencePolicyEnum? degradedReferencePolicy;

  @JsonKey(
    defaultValue: 'default',
    name: r'default_preset',
    required: false,
    includeIfNull: false,
  )
  final String? defaultPreset;

  @JsonKey(
    defaultValue: '',
    name: r'active_preset',
    required: false,
    includeIfNull: false,
  )
  final String? activePreset;

  @JsonKey(
    defaultValue: {},
    name: r'presets',
    required: false,
    includeIfNull: false,
  )
  final Map<String, MoaPresetPayload>? presets;

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

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoaConfigPayload &&
          other.referenceTimeout == referenceTimeout &&
          other.degradedReferencePolicy == degradedReferencePolicy &&
          other.defaultPreset == defaultPreset &&
          other.activePreset == activePreset &&
          other.presets == presets &&
          other.referenceModels == referenceModels &&
          other.aggregator == aggregator &&
          other.referenceTemperature == referenceTemperature &&
          other.aggregatorTemperature == aggregatorTemperature &&
          other.fanout == fanout &&
          other.enabled == enabled &&
          other.profile == profile;

  @override
  int get hashCode =>
      (referenceTimeout == null ? 0 : referenceTimeout.hashCode) +
      degradedReferencePolicy.hashCode +
      defaultPreset.hashCode +
      activePreset.hashCode +
      presets.hashCode +
      referenceModels.hashCode +
      aggregator.hashCode +
      (referenceTemperature == null ? 0 : referenceTemperature.hashCode) +
      (aggregatorTemperature == null ? 0 : aggregatorTemperature.hashCode) +
      (fanout == null ? 0 : fanout.hashCode) +
      enabled.hashCode +
      (profile == null ? 0 : profile.hashCode);

  factory MoaConfigPayload.fromJson(Map<String, dynamic> json) =>
      _$MoaConfigPayloadFromJson(json);

  Map<String, dynamic> toJson() => _$MoaConfigPayloadToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}

enum MoaConfigPayloadDegradedReferencePolicyEnum {
  @JsonValue(r'loud')
  loud(r'loud'),
  @JsonValue(r'silent')
  silent(r'silent'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const MoaConfigPayloadDegradedReferencePolicyEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
