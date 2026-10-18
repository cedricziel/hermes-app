// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'estimate_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$EstimateBodyCWProxy {
  EstimateBody title(String? title);

  EstimateBody body(String? body);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `EstimateBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// EstimateBody(...).copyWith(id: 12, name: "My name")
  /// ```
  EstimateBody call({String? title, String? body});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfEstimateBody.copyWith(...)` or call `instanceOfEstimateBody.copyWith.fieldName(value)` for a single field.
class _$EstimateBodyCWProxyImpl implements _$EstimateBodyCWProxy {
  const _$EstimateBodyCWProxyImpl(this._value);

  final EstimateBody _value;

  @override
  EstimateBody title(String? title) => call(title: title);

  @override
  EstimateBody body(String? body) => call(body: body);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `EstimateBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// EstimateBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  EstimateBody call({
    Object? title = const $CopyWithPlaceholder(),
    Object? body = const $CopyWithPlaceholder(),
  }) {
    return EstimateBody(
      title: title == const $CopyWithPlaceholder()
          ? _value.title
          // ignore: cast_nullable_to_non_nullable
          : title as String?,
      body: body == const $CopyWithPlaceholder()
          ? _value.body
          // ignore: cast_nullable_to_non_nullable
          : body as String?,
    );
  }
}

extension $EstimateBodyCopyWith on EstimateBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfEstimateBody.copyWith(...)` or `instanceOfEstimateBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$EstimateBodyCWProxy get copyWith => _$EstimateBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EstimateBody _$EstimateBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('EstimateBody', json, ($checkedConvert) {
      final val = EstimateBody(
        title: $checkedConvert('title', (v) => v as String? ?? ''),
        body: $checkedConvert('body', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$EstimateBodyToJson(EstimateBody instance) =>
    <String, dynamic>{'title': ?instance.title, 'body': ?instance.body};
