// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_activate_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ModelActivateBodyCWProxy {
  ModelActivateBody modelId(String modelId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ModelActivateBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ModelActivateBody(...).copyWith(id: 12, name: "My name")
  /// ```
  ModelActivateBody call({String modelId});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfModelActivateBody.copyWith(...)` or call `instanceOfModelActivateBody.copyWith.fieldName(value)` for a single field.
class _$ModelActivateBodyCWProxyImpl implements _$ModelActivateBodyCWProxy {
  const _$ModelActivateBodyCWProxyImpl(this._value);

  final ModelActivateBody _value;

  @override
  ModelActivateBody modelId(String modelId) => call(modelId: modelId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ModelActivateBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ModelActivateBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ModelActivateBody call({Object? modelId = const $CopyWithPlaceholder()}) {
    return ModelActivateBody(
      modelId: modelId == const $CopyWithPlaceholder() || modelId == null
          ? _value.modelId
          // ignore: cast_nullable_to_non_nullable
          : modelId as String,
    );
  }
}

extension $ModelActivateBodyCopyWith on ModelActivateBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfModelActivateBody.copyWith(...)` or `instanceOfModelActivateBody.copyWith.fieldName(...)`.
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
