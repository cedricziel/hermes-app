// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'describe_auto_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DescribeAutoBodyCWProxy {
  DescribeAutoBody overwrite(bool? overwrite);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DescribeAutoBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DescribeAutoBody(...).copyWith(id: 12, name: "My name")
  /// ```
  DescribeAutoBody call({bool? overwrite});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfDescribeAutoBody.copyWith(...)` or call `instanceOfDescribeAutoBody.copyWith.fieldName(value)` for a single field.
class _$DescribeAutoBodyCWProxyImpl implements _$DescribeAutoBodyCWProxy {
  const _$DescribeAutoBodyCWProxyImpl(this._value);

  final DescribeAutoBody _value;

  @override
  DescribeAutoBody overwrite(bool? overwrite) => call(overwrite: overwrite);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `DescribeAutoBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// DescribeAutoBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  DescribeAutoBody call({Object? overwrite = const $CopyWithPlaceholder()}) {
    return DescribeAutoBody(
      overwrite: overwrite == const $CopyWithPlaceholder()
          ? _value.overwrite
          // ignore: cast_nullable_to_non_nullable
          : overwrite as bool?,
    );
  }
}

extension $DescribeAutoBodyCopyWith on DescribeAutoBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfDescribeAutoBody.copyWith(...)` or `instanceOfDescribeAutoBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$DescribeAutoBodyCWProxy get copyWith => _$DescribeAutoBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DescribeAutoBody _$DescribeAutoBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('DescribeAutoBody', json, ($checkedConvert) {
      final val = DescribeAutoBody(
        overwrite: $checkedConvert('overwrite', (v) => v as bool? ?? false),
      );
      return val;
    });

Map<String, dynamic> _$DescribeAutoBodyToJson(DescribeAutoBody instance) =>
    <String, dynamic>{'overwrite': ?instance.overwrite};
