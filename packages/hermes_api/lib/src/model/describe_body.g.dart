// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'describe_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DescribeBodyCWProxy {
  DescribeBody description(String? description);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DescribeBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DescribeBody(...).copyWith(id: 12, name: "My name")
  /// ```
  DescribeBody call({String? description});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDescribeBody.copyWith(...)` or call `instanceOfDescribeBody.copyWith.fieldName(value)` for a single field.
class _$DescribeBodyCWProxyImpl implements _$DescribeBodyCWProxy {
  const _$DescribeBodyCWProxyImpl(this._value);

  final DescribeBody _value;

  @override
  DescribeBody description(String? description) =>
      call(description: description);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DescribeBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DescribeBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DescribeBody call({Object? description = const $CopyWithPlaceholder()}) {
    return DescribeBody(
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String?,
    );
  }
}

extension $DescribeBodyCopyWith on DescribeBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDescribeBody.copyWith(...)` or `instanceOfDescribeBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DescribeBodyCWProxy get copyWith => _$DescribeBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DescribeBody _$DescribeBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DescribeBody', json, ($checkedConvert) {
      final val = DescribeBody(
        description: $checkedConvert('description', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$DescribeBodyToJson(DescribeBody instance) =>
    <String, dynamic>{'description': ?instance.description};
