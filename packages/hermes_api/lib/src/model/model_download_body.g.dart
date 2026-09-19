// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_download_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ModelDownloadBodyCWProxy {
  ModelDownloadBody modelId(String modelId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ModelDownloadBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ModelDownloadBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ModelDownloadBody call({String modelId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfModelDownloadBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfModelDownloadBody.copyWith.fieldName(...)`
class _$ModelDownloadBodyCWProxyImpl implements _$ModelDownloadBodyCWProxy {
  const _$ModelDownloadBodyCWProxyImpl(this._value);

  final ModelDownloadBody _value;

  @override
  ModelDownloadBody modelId(String modelId) => this(modelId: modelId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ModelDownloadBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ModelDownloadBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ModelDownloadBody call({Object? modelId = const $CopyWithPlaceholder()}) {
    return ModelDownloadBody(
      modelId: modelId == const $CopyWithPlaceholder()
          ? _value.modelId
          // ignore: cast_nullable_to_non_nullable
          : modelId as String,
    );
  }
}

extension $ModelDownloadBodyCopyWith on ModelDownloadBody {
  /// Returns a callable class that can be used as follows: `instanceOfModelDownloadBody.copyWith(...)` or like so:`instanceOfModelDownloadBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ModelDownloadBodyCWProxy get copyWith =>
      _$ModelDownloadBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModelDownloadBody _$ModelDownloadBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ModelDownloadBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['model_id']);
      final val = ModelDownloadBody(
        modelId: $checkedConvert('model_id', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'modelId': 'model_id'});

Map<String, dynamic> _$ModelDownloadBodyToJson(ModelDownloadBody instance) =>
    <String, dynamic>{'model_id': instance.modelId};
