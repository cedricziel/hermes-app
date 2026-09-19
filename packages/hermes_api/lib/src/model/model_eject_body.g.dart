// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_eject_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ModelEjectBodyCWProxy {
  ModelEjectBody modelId(String modelId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ModelEjectBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ModelEjectBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ModelEjectBody call({String modelId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfModelEjectBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfModelEjectBody.copyWith.fieldName(...)`
class _$ModelEjectBodyCWProxyImpl implements _$ModelEjectBodyCWProxy {
  const _$ModelEjectBodyCWProxyImpl(this._value);

  final ModelEjectBody _value;

  @override
  ModelEjectBody modelId(String modelId) => this(modelId: modelId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ModelEjectBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ModelEjectBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ModelEjectBody call({Object? modelId = const $CopyWithPlaceholder()}) {
    return ModelEjectBody(
      modelId: modelId == const $CopyWithPlaceholder()
          ? _value.modelId
          // ignore: cast_nullable_to_non_nullable
          : modelId as String,
    );
  }
}

extension $ModelEjectBodyCopyWith on ModelEjectBody {
  /// Returns a callable class that can be used as follows: `instanceOfModelEjectBody.copyWith(...)` or like so:`instanceOfModelEjectBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ModelEjectBodyCWProxy get copyWith => _$ModelEjectBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModelEjectBody _$ModelEjectBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ModelEjectBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['model_id']);
      final val = ModelEjectBody(
        modelId: $checkedConvert('model_id', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'modelId': 'model_id'});

Map<String, dynamic> _$ModelEjectBodyToJson(ModelEjectBody instance) =>
    <String, dynamic>{'model_id': instance.modelId};
