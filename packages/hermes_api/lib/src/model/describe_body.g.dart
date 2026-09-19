// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'describe_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$DescribeBodyCWProxy {
  DescribeBody description(String? description);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DescribeBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DescribeBody(...).copyWith(id: 12, name: "My name")
  /// ````
  DescribeBody call({String? description});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfDescribeBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfDescribeBody.copyWith.fieldName(...)`
class _$DescribeBodyCWProxyImpl implements _$DescribeBodyCWProxy {
  const _$DescribeBodyCWProxyImpl(this._value);

  final DescribeBody _value;

  @override
  DescribeBody description(String? description) =>
      this(description: description);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `DescribeBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// DescribeBody(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfDescribeBody.copyWith(...)` or like so:`instanceOfDescribeBody.copyWith.fieldName(...)`.
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
