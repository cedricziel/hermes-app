// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moa_preset_payload.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MoaPresetPayloadCWProxy {
  MoaPresetPayload referenceTimeout(num? referenceTimeout);

  MoaPresetPayload degradedReferencePolicy(
    MoaPresetPayloadDegradedReferencePolicyEnum? degradedReferencePolicy,
  );

  MoaPresetPayload referenceModels(List<MoaModelSlot>? referenceModels);

  MoaPresetPayload aggregator(MoaModelSlot? aggregator);

  MoaPresetPayload referenceTemperature(num? referenceTemperature);

  MoaPresetPayload aggregatorTemperature(num? aggregatorTemperature);

  MoaPresetPayload fanout(String? fanout);

  MoaPresetPayload enabled(bool? enabled);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MoaPresetPayload(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MoaPresetPayload(...).copyWith(id: 12, name: "My name")
  /// ````
  MoaPresetPayload call({
    num? referenceTimeout,
    MoaPresetPayloadDegradedReferencePolicyEnum? degradedReferencePolicy,
    List<MoaModelSlot>? referenceModels,
    MoaModelSlot? aggregator,
    num? referenceTemperature,
    num? aggregatorTemperature,
    String? fanout,
    bool? enabled,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMoaPresetPayload.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMoaPresetPayload.copyWith.fieldName(...)`
class _$MoaPresetPayloadCWProxyImpl implements _$MoaPresetPayloadCWProxy {
  const _$MoaPresetPayloadCWProxyImpl(this._value);

  final MoaPresetPayload _value;

  @override
  MoaPresetPayload referenceTimeout(num? referenceTimeout) =>
      this(referenceTimeout: referenceTimeout);

  @override
  MoaPresetPayload degradedReferencePolicy(
    MoaPresetPayloadDegradedReferencePolicyEnum? degradedReferencePolicy,
  ) => this(degradedReferencePolicy: degradedReferencePolicy);

  @override
  MoaPresetPayload referenceModels(List<MoaModelSlot>? referenceModels) =>
      this(referenceModels: referenceModels);

  @override
  MoaPresetPayload aggregator(MoaModelSlot? aggregator) =>
      this(aggregator: aggregator);

  @override
  MoaPresetPayload referenceTemperature(num? referenceTemperature) =>
      this(referenceTemperature: referenceTemperature);

  @override
  MoaPresetPayload aggregatorTemperature(num? aggregatorTemperature) =>
      this(aggregatorTemperature: aggregatorTemperature);

  @override
  MoaPresetPayload fanout(String? fanout) => this(fanout: fanout);

  @override
  MoaPresetPayload enabled(bool? enabled) => this(enabled: enabled);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MoaPresetPayload(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MoaPresetPayload(...).copyWith(id: 12, name: "My name")
  /// ````
  MoaPresetPayload call({
    Object? referenceTimeout = const $CopyWithPlaceholder(),
    Object? degradedReferencePolicy = const $CopyWithPlaceholder(),
    Object? referenceModels = const $CopyWithPlaceholder(),
    Object? aggregator = const $CopyWithPlaceholder(),
    Object? referenceTemperature = const $CopyWithPlaceholder(),
    Object? aggregatorTemperature = const $CopyWithPlaceholder(),
    Object? fanout = const $CopyWithPlaceholder(),
    Object? enabled = const $CopyWithPlaceholder(),
  }) {
    return MoaPresetPayload(
      referenceTimeout: referenceTimeout == const $CopyWithPlaceholder()
          ? _value.referenceTimeout
          // ignore: cast_nullable_to_non_nullable
          : referenceTimeout as num?,
      degradedReferencePolicy:
          degradedReferencePolicy == const $CopyWithPlaceholder()
          ? _value.degradedReferencePolicy
          // ignore: cast_nullable_to_non_nullable
          : degradedReferencePolicy
                as MoaPresetPayloadDegradedReferencePolicyEnum?,
      referenceModels: referenceModels == const $CopyWithPlaceholder()
          ? _value.referenceModels
          // ignore: cast_nullable_to_non_nullable
          : referenceModels as List<MoaModelSlot>?,
      aggregator: aggregator == const $CopyWithPlaceholder()
          ? _value.aggregator
          // ignore: cast_nullable_to_non_nullable
          : aggregator as MoaModelSlot?,
      referenceTemperature: referenceTemperature == const $CopyWithPlaceholder()
          ? _value.referenceTemperature
          // ignore: cast_nullable_to_non_nullable
          : referenceTemperature as num?,
      aggregatorTemperature:
          aggregatorTemperature == const $CopyWithPlaceholder()
          ? _value.aggregatorTemperature
          // ignore: cast_nullable_to_non_nullable
          : aggregatorTemperature as num?,
      fanout: fanout == const $CopyWithPlaceholder()
          ? _value.fanout
          // ignore: cast_nullable_to_non_nullable
          : fanout as String?,
      enabled: enabled == const $CopyWithPlaceholder()
          ? _value.enabled
          // ignore: cast_nullable_to_non_nullable
          : enabled as bool?,
    );
  }
}

extension $MoaPresetPayloadCopyWith on MoaPresetPayload {
  /// Returns a callable class that can be used as follows: `instanceOfMoaPresetPayload.copyWith(...)` or like so:`instanceOfMoaPresetPayload.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MoaPresetPayloadCWProxy get copyWith => _$MoaPresetPayloadCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoaPresetPayload _$MoaPresetPayloadFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'MoaPresetPayload',
  json,
  ($checkedConvert) {
    final val = MoaPresetPayload(
      referenceTimeout: $checkedConvert('reference_timeout', (v) => v as num?),
      degradedReferencePolicy: $checkedConvert(
        'degraded_reference_policy',
        (v) =>
            $enumDecodeNullable(
              _$MoaPresetPayloadDegradedReferencePolicyEnumEnumMap,
              v,
              unknownValue: MoaPresetPayloadDegradedReferencePolicyEnum
                  .unknownDefaultOpenApi,
            ) ??
            MoaPresetPayloadDegradedReferencePolicyEnum.loud,
      ),
      referenceModels: $checkedConvert(
        'reference_models',
        (v) =>
            (v as List<dynamic>?)
                ?.map((e) => MoaModelSlot.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      ),
      aggregator: $checkedConvert(
        'aggregator',
        (v) =>
            v == null ? null : MoaModelSlot.fromJson(v as Map<String, dynamic>),
      ),
      referenceTemperature: $checkedConvert(
        'reference_temperature',
        (v) => v as num?,
      ),
      aggregatorTemperature: $checkedConvert(
        'aggregator_temperature',
        (v) => v as num?,
      ),
      fanout: $checkedConvert('fanout', (v) => v as String?),
      enabled: $checkedConvert('enabled', (v) => v as bool? ?? true),
    );
    return val;
  },
  fieldKeyMap: const {
    'referenceTimeout': 'reference_timeout',
    'degradedReferencePolicy': 'degraded_reference_policy',
    'referenceModels': 'reference_models',
    'referenceTemperature': 'reference_temperature',
    'aggregatorTemperature': 'aggregator_temperature',
  },
);

Map<String, dynamic> _$MoaPresetPayloadToJson(MoaPresetPayload instance) =>
    <String, dynamic>{
      'reference_timeout': ?instance.referenceTimeout,
      'degraded_reference_policy':
          ?_$MoaPresetPayloadDegradedReferencePolicyEnumEnumMap[instance
              .degradedReferencePolicy],
      'reference_models': ?instance.referenceModels
          ?.map((e) => e.toJson())
          .toList(),
      'aggregator': ?instance.aggregator?.toJson(),
      'reference_temperature': ?instance.referenceTemperature,
      'aggregator_temperature': ?instance.aggregatorTemperature,
      'fanout': ?instance.fanout,
      'enabled': ?instance.enabled,
    };

const _$MoaPresetPayloadDegradedReferencePolicyEnumEnumMap = {
  MoaPresetPayloadDegradedReferencePolicyEnum.loud: 'loud',
  MoaPresetPayloadDegradedReferencePolicyEnum.silent: 'silent',
  MoaPresetPayloadDegradedReferencePolicyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
