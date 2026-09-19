// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_activate_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ModelActivateBodyCWProxy {
  ModelActivateBody modelId(String modelId);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ModelActivateBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ModelActivateBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ModelActivateBody call({String modelId});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfModelActivateBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfModelActivateBody.copyWith.fieldName(...)`
class _$ModelActivateBodyCWProxyImpl implements _$ModelActivateBodyCWProxy {
  const _$ModelActivateBodyCWProxyImpl(this._value);

  final ModelActivateBody _value;

  @override
  ModelActivateBody modelId(String modelId) => this(modelId: modelId);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ModelActivateBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ModelActivateBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ModelActivateBody call({Object? modelId = const $CopyWithPlaceholder()}) {
    return ModelActivateBody(
      modelId: modelId == const $CopyWithPlaceholder()
          ? _value.modelId
          // ignore: cast_nullable_to_non_nullable
          : modelId as String,
    );
  }
}

extension $ModelActivateBodyCopyWith on ModelActivateBody {
  /// Returns a callable class that can be used as follows: `instanceOfModelActivateBody.copyWith(...)` or like so:`instanceOfModelActivateBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ModelActivateBodyCWProxy get copyWith =>
      _$ModelActivateBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModelActivateBody _$ModelActivateBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ModelActivateBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['model_id']);
      final val = ModelActivateBody(
        modelId: $checkedConvert('model_id', (v) => v as String),
      );
      return val;
    }, fieldKeyMap: const {'modelId': 'model_id'});

Map<String, dynamic> _$ModelActivateBodyToJson(ModelActivateBody instance) =>
    <String, dynamic>{'model_id': instance.modelId};
