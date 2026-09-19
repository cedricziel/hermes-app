// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'moa_config_payload.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MoaConfigPayloadCWProxy {
  MoaConfigPayload referenceTimeout(num? referenceTimeout);

  MoaConfigPayload degradedReferencePolicy(
    MoaConfigPayloadDegradedReferencePolicyEnum? degradedReferencePolicy,
  );

  MoaConfigPayload defaultPreset(String? defaultPreset);

  MoaConfigPayload activePreset(String? activePreset);

  MoaConfigPayload presets(Map<String, MoaPresetPayload>? presets);

  MoaConfigPayload referenceModels(List<MoaModelSlot>? referenceModels);

  MoaConfigPayload aggregator(MoaModelSlot? aggregator);

  MoaConfigPayload referenceTemperature(num? referenceTemperature);

  MoaConfigPayload aggregatorTemperature(num? aggregatorTemperature);

  MoaConfigPayload fanout(String? fanout);

  MoaConfigPayload enabled(bool? enabled);

  MoaConfigPayload profile(String? profile);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MoaConfigPayload(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MoaConfigPayload(...).copyWith(id: 12, name: "My name")
  /// ````
  MoaConfigPayload call({
    num? referenceTimeout,
    MoaConfigPayloadDegradedReferencePolicyEnum? degradedReferencePolicy,
    String? defaultPreset,
    String? activePreset,
    Map<String, MoaPresetPayload>? presets,
    List<MoaModelSlot>? referenceModels,
    MoaModelSlot? aggregator,
    num? referenceTemperature,
    num? aggregatorTemperature,
    String? fanout,
    bool? enabled,
    String? profile,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMoaConfigPayload.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMoaConfigPayload.copyWith.fieldName(...)`
class _$MoaConfigPayloadCWProxyImpl implements _$MoaConfigPayloadCWProxy {
  const _$MoaConfigPayloadCWProxyImpl(this._value);

  final MoaConfigPayload _value;

  @override
  MoaConfigPayload referenceTimeout(num? referenceTimeout) =>
      this(referenceTimeout: referenceTimeout);

  @override
  MoaConfigPayload degradedReferencePolicy(
    MoaConfigPayloadDegradedReferencePolicyEnum? degradedReferencePolicy,
  ) => this(degradedReferencePolicy: degradedReferencePolicy);

  @override
  MoaConfigPayload defaultPreset(String? defaultPreset) =>
      this(defaultPreset: defaultPreset);

  @override
  MoaConfigPayload activePreset(String? activePreset) =>
      this(activePreset: activePreset);

  @override
  MoaConfigPayload presets(Map<String, MoaPresetPayload>? presets) =>
      this(presets: presets);

  @override
  MoaConfigPayload referenceModels(List<MoaModelSlot>? referenceModels) =>
      this(referenceModels: referenceModels);

  @override
  MoaConfigPayload aggregator(MoaModelSlot? aggregator) =>
      this(aggregator: aggregator);

  @override
  MoaConfigPayload referenceTemperature(num? referenceTemperature) =>
      this(referenceTemperature: referenceTemperature);

  @override
  MoaConfigPayload aggregatorTemperature(num? aggregatorTemperature) =>
      this(aggregatorTemperature: aggregatorTemperature);

  @override
  MoaConfigPayload fanout(String? fanout) => this(fanout: fanout);

  @override
  MoaConfigPayload enabled(bool? enabled) => this(enabled: enabled);

  @override
  MoaConfigPayload profile(String? profile) => this(profile: profile);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MoaConfigPayload(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MoaConfigPayload(...).copyWith(id: 12, name: "My name")
  /// ````
  MoaConfigPayload call({
    Object? referenceTimeout = const $CopyWithPlaceholder(),
    Object? degradedReferencePolicy = const $CopyWithPlaceholder(),
    Object? defaultPreset = const $CopyWithPlaceholder(),
    Object? activePreset = const $CopyWithPlaceholder(),
    Object? presets = const $CopyWithPlaceholder(),
    Object? referenceModels = const $CopyWithPlaceholder(),
    Object? aggregator = const $CopyWithPlaceholder(),
    Object? referenceTemperature = const $CopyWithPlaceholder(),
    Object? aggregatorTemperature = const $CopyWithPlaceholder(),
    Object? fanout = const $CopyWithPlaceholder(),
    Object? enabled = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return MoaConfigPayload(
      referenceTimeout: referenceTimeout == const $CopyWithPlaceholder()
          ? _value.referenceTimeout
          // ignore: cast_nullable_to_non_nullable
          : referenceTimeout as num?,
      degradedReferencePolicy:
          degradedReferencePolicy == const $CopyWithPlaceholder()
          ? _value.degradedReferencePolicy
          // ignore: cast_nullable_to_non_nullable
          : degradedReferencePolicy
                as MoaConfigPayloadDegradedReferencePolicyEnum?,
      defaultPreset: defaultPreset == const $CopyWithPlaceholder()
          ? _value.defaultPreset
          // ignore: cast_nullable_to_non_nullable
          : defaultPreset as String?,
      activePreset: activePreset == const $CopyWithPlaceholder()
          ? _value.activePreset
          // ignore: cast_nullable_to_non_nullable
          : activePreset as String?,
      presets: presets == const $CopyWithPlaceholder()
          ? _value.presets
          // ignore: cast_nullable_to_non_nullable
          : presets as Map<String, MoaPresetPayload>?,
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
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $MoaConfigPayloadCopyWith on MoaConfigPayload {
  /// Returns a callable class that can be used as follows: `instanceOfMoaConfigPayload.copyWith(...)` or like so:`instanceOfMoaConfigPayload.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MoaConfigPayloadCWProxy get copyWith => _$MoaConfigPayloadCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MoaConfigPayload _$MoaConfigPayloadFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'MoaConfigPayload',
  json,
  ($checkedConvert) {
    final val = MoaConfigPayload(
      referenceTimeout: $checkedConvert('reference_timeout', (v) => v as num?),
      degradedReferencePolicy: $checkedConvert(
        'degraded_reference_policy',
        (v) =>
            $enumDecodeNullable(
              _$MoaConfigPayloadDegradedReferencePolicyEnumEnumMap,
              v,
              unknownValue: MoaConfigPayloadDegradedReferencePolicyEnum
                  .unknownDefaultOpenApi,
            ) ??
            MoaConfigPayloadDegradedReferencePolicyEnum.loud,
      ),
      defaultPreset: $checkedConvert(
        'default_preset',
        (v) => v as String? ?? 'default',
      ),
      activePreset: $checkedConvert('active_preset', (v) => v as String? ?? ''),
      presets: $checkedConvert(
        'presets',
        (v) =>
            (v as Map<String, dynamic>?)?.map(
              (k, e) => MapEntry(
                k,
                MoaPresetPayload.fromJson(e as Map<String, dynamic>),
              ),
            ) ??
            {},
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
      profile: $checkedConvert('profile', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'referenceTimeout': 'reference_timeout',
    'degradedReferencePolicy': 'degraded_reference_policy',
    'defaultPreset': 'default_preset',
    'activePreset': 'active_preset',
    'referenceModels': 'reference_models',
    'referenceTemperature': 'reference_temperature',
    'aggregatorTemperature': 'aggregator_temperature',
  },
);

Map<String, dynamic> _$MoaConfigPayloadToJson(MoaConfigPayload instance) =>
    <String, dynamic>{
      'reference_timeout': ?instance.referenceTimeout,
      'degraded_reference_policy':
          ?_$MoaConfigPayloadDegradedReferencePolicyEnumEnumMap[instance
              .degradedReferencePolicy],
      'default_preset': ?instance.defaultPreset,
      'active_preset': ?instance.activePreset,
      'presets': ?instance.presets?.map((k, e) => MapEntry(k, e.toJson())),
      'reference_models': ?instance.referenceModels
          ?.map((e) => e.toJson())
          .toList(),
      'aggregator': ?instance.aggregator?.toJson(),
      'reference_temperature': ?instance.referenceTemperature,
      'aggregator_temperature': ?instance.aggregatorTemperature,
      'fanout': ?instance.fanout,
      'enabled': ?instance.enabled,
      'profile': ?instance.profile,
    };

const _$MoaConfigPayloadDegradedReferencePolicyEnumEnumMap = {
  MoaConfigPayloadDegradedReferencePolicyEnum.loud: 'loud',
  MoaConfigPayloadDegradedReferencePolicyEnum.silent: 'silent',
  MoaConfigPayloadDegradedReferencePolicyEnum.unknownDefaultOpenApi:
      'unknown_default_open_api',
};
