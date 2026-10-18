// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_eject_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ModelEjectBodyCWProxy {
  ModelEjectBody modelId(String modelId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ModelEjectBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ModelEjectBody(...).copyWith(id: 12, name: "My name")
  /// ```
  ModelEjectBody call({String modelId});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfModelEjectBody.copyWith(...)` or call `instanceOfModelEjectBody.copyWith.fieldName(value)` for a single field.
class _$ModelEjectBodyCWProxyImpl implements _$ModelEjectBodyCWProxy {
  const _$ModelEjectBodyCWProxyImpl(this._value);

  final ModelEjectBody _value;

  @override
  ModelEjectBody modelId(String modelId) => call(modelId: modelId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ModelEjectBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ModelEjectBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ModelEjectBody call({Object? modelId = const $CopyWithPlaceholder()}) {
    return ModelEjectBody(
      modelId: modelId == const $CopyWithPlaceholder() || modelId == null
          ? _value.modelId
          // ignore: cast_nullable_to_non_nullable
          : modelId as String,
    );
  }
}

extension $ModelEjectBodyCopyWith on ModelEjectBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfModelEjectBody.copyWith(...)` or `instanceOfModelEjectBody.copyWith.fieldName(...)`.
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
