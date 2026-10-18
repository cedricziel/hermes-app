// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'http_validation_error.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$HTTPValidationErrorCWProxy {
  HTTPValidationError detail(List<ValidationError>? detail);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `HTTPValidationError(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// HTTPValidationError(...).copyWith(id: 12, name: "My name")
  /// ```
  HTTPValidationError call({List<ValidationError>? detail});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfHTTPValidationError.copyWith(...)` or call `instanceOfHTTPValidationError.copyWith.fieldName(value)` for a single field.
class _$HTTPValidationErrorCWProxyImpl implements _$HTTPValidationErrorCWProxy {
  const _$HTTPValidationErrorCWProxyImpl(this._value);

  final HTTPValidationError _value;

  @override
  HTTPValidationError detail(List<ValidationError>? detail) =>
      call(detail: detail);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `HTTPValidationError(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// HTTPValidationError(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  HTTPValidationError call({Object? detail = const $CopyWithPlaceholder()}) {
    return HTTPValidationError(
      detail: detail == const $CopyWithPlaceholder()
          ? _value.detail
          // ignore: cast_nullable_to_non_nullable
          : detail as List<ValidationError>?,
    );
  }
}

extension $HTTPValidationErrorCopyWith on HTTPValidationError {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfHTTPValidationError.copyWith(...)` or `instanceOfHTTPValidationError.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$HTTPValidationErrorCWProxy get copyWith =>
      _$HTTPValidationErrorCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

HTTPValidationError _$HTTPValidationErrorFromJson(Map<String, dynamic> json) =>
    $checkedCreate('HTTPValidationError', json, ($checkedConvert) {
      final val = HTTPValidationError(
        detail: $checkedConvert(
          'detail',
          (v) => (v as List<dynamic>?)
              ?.map((e) => ValidationError.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$HTTPValidationErrorToJson(
  HTTPValidationError instance,
) => <String, dynamic>{
  'detail': ?instance.detail?.map((e) => e.toJson()).toList(),
};
