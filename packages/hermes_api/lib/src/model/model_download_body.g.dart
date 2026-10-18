// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_download_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ModelDownloadBodyCWProxy {
  ModelDownloadBody modelId(String modelId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ModelDownloadBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ModelDownloadBody(...).copyWith(id: 12, name: "My name")
  /// ```
  ModelDownloadBody call({String modelId});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfModelDownloadBody.copyWith(...)` or call `instanceOfModelDownloadBody.copyWith.fieldName(value)` for a single field.
class _$ModelDownloadBodyCWProxyImpl implements _$ModelDownloadBodyCWProxy {
  const _$ModelDownloadBodyCWProxyImpl(this._value);

  final ModelDownloadBody _value;

  @override
  ModelDownloadBody modelId(String modelId) => call(modelId: modelId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ModelDownloadBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ModelDownloadBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ModelDownloadBody call({Object? modelId = const $CopyWithPlaceholder()}) {
    return ModelDownloadBody(
      modelId: modelId == const $CopyWithPlaceholder() || modelId == null
          ? _value.modelId
          // ignore: cast_nullable_to_non_nullable
          : modelId as String,
    );
  }
}

extension $ModelDownloadBodyCopyWith on ModelDownloadBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfModelDownloadBody.copyWith(...)` or `instanceOfModelDownloadBody.copyWith.fieldName(...)`.
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
