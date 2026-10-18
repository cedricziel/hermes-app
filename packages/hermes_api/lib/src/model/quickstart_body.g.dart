// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'quickstart_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$QuickstartBodyCWProxy {
  QuickstartBody modelId(String? modelId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `QuickstartBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// QuickstartBody(...).copyWith(id: 12, name: "My name")
  /// ```
  QuickstartBody call({String? modelId});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfQuickstartBody.copyWith(...)` or call `instanceOfQuickstartBody.copyWith.fieldName(value)` for a single field.
class _$QuickstartBodyCWProxyImpl implements _$QuickstartBodyCWProxy {
  const _$QuickstartBodyCWProxyImpl(this._value);

  final QuickstartBody _value;

  @override
  QuickstartBody modelId(String? modelId) => call(modelId: modelId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `QuickstartBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// QuickstartBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  QuickstartBody call({Object? modelId = const $CopyWithPlaceholder()}) {
    return QuickstartBody(
      modelId: modelId == const $CopyWithPlaceholder()
          ? _value.modelId
          // ignore: cast_nullable_to_non_nullable
          : modelId as String?,
    );
  }
}

extension $QuickstartBodyCopyWith on QuickstartBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfQuickstartBody.copyWith(...)` or `instanceOfQuickstartBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$QuickstartBodyCWProxy get copyWith => _$QuickstartBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

QuickstartBody _$QuickstartBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('QuickstartBody', json, ($checkedConvert) {
      final val = QuickstartBody(
        modelId: $checkedConvert('model_id', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'modelId': 'model_id'});

Map<String, dynamic> _$QuickstartBodyToJson(QuickstartBody instance) =>
    <String, dynamic>{'model_id': ?instance.modelId};
