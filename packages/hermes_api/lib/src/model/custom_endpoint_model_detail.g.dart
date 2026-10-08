// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_endpoint_model_detail.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CustomEndpointModelDetailCWProxy {
  CustomEndpointModelDetail id(String id);

  CustomEndpointModelDetail canonicalModel(String? canonicalModel);

  CustomEndpointModelDetail reasoningEffort(String? reasoningEffort);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CustomEndpointModelDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CustomEndpointModelDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  CustomEndpointModelDetail call({
    String id,
    String? canonicalModel,
    String? reasoningEffort,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCustomEndpointModelDetail.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCustomEndpointModelDetail.copyWith.fieldName(...)`
class _$CustomEndpointModelDetailCWProxyImpl
    implements _$CustomEndpointModelDetailCWProxy {
  const _$CustomEndpointModelDetailCWProxyImpl(this._value);

  final CustomEndpointModelDetail _value;

  @override
  CustomEndpointModelDetail id(String id) => this(id: id);

  @override
  CustomEndpointModelDetail canonicalModel(String? canonicalModel) =>
      this(canonicalModel: canonicalModel);

  @override
  CustomEndpointModelDetail reasoningEffort(String? reasoningEffort) =>
      this(reasoningEffort: reasoningEffort);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CustomEndpointModelDetail(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CustomEndpointModelDetail(...).copyWith(id: 12, name: "My name")
  /// ````
  CustomEndpointModelDetail call({
    Object? id = const $CopyWithPlaceholder(),
    Object? canonicalModel = const $CopyWithPlaceholder(),
    Object? reasoningEffort = const $CopyWithPlaceholder(),
  }) {
    return CustomEndpointModelDetail(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String,
      canonicalModel: canonicalModel == const $CopyWithPlaceholder()
          ? _value.canonicalModel
          // ignore: cast_nullable_to_non_nullable
          : canonicalModel as String?,
      reasoningEffort: reasoningEffort == const $CopyWithPlaceholder()
          ? _value.reasoningEffort
          // ignore: cast_nullable_to_non_nullable
          : reasoningEffort as String?,
    );
  }
}

extension $CustomEndpointModelDetailCopyWith on CustomEndpointModelDetail {
  /// Returns a callable class that can be used as follows: `instanceOfCustomEndpointModelDetail.copyWith(...)` or like so:`instanceOfCustomEndpointModelDetail.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CustomEndpointModelDetailCWProxy get copyWith =>
      _$CustomEndpointModelDetailCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomEndpointModelDetail _$CustomEndpointModelDetailFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CustomEndpointModelDetail',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['id']);
    final val = CustomEndpointModelDetail(
      id: $checkedConvert('id', (v) => v as String),
      canonicalModel: $checkedConvert('canonical_model', (v) => v as String?),
      reasoningEffort: $checkedConvert('reasoning_effort', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'canonicalModel': 'canonical_model',
    'reasoningEffort': 'reasoning_effort',
  },
);

Map<String, dynamic> _$CustomEndpointModelDetailToJson(
  CustomEndpointModelDetail instance,
) => <String, dynamic>{
  'id': instance.id,
  'canonical_model': ?instance.canonicalModel,
  'reasoning_effort': ?instance.reasoningEffort,
};
