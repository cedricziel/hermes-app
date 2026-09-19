// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'describe_auto_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DescribeAutoBodyCWProxy {
  DescribeAutoBody overwrite(bool? overwrite);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DescribeAutoBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DescribeAutoBody(...).copyWith(id: 12, name: "My name")
  /// ````
  DescribeAutoBody call({bool? overwrite});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDescribeAutoBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDescribeAutoBody.copyWith.fieldName(...)`
class _$DescribeAutoBodyCWProxyImpl implements _$DescribeAutoBodyCWProxy {
  const _$DescribeAutoBodyCWProxyImpl(this._value);

  final DescribeAutoBody _value;

  @override
  DescribeAutoBody overwrite(bool? overwrite) => this(overwrite: overwrite);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DescribeAutoBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DescribeAutoBody(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfDescribeAutoBody.copyWith(...)` or like so:`instanceOfDescribeAutoBody.copyWith.fieldName(...)`.
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
