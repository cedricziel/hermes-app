// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_describe_auto.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileDescribeAutoCWProxy {
  ProfileDescribeAuto overwrite(bool? overwrite);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileDescribeAuto(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileDescribeAuto(...).copyWith(id: 12, name: "My name")
  /// ```
  ProfileDescribeAuto call({bool? overwrite});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfileDescribeAuto.copyWith(...)` or call `instanceOfProfileDescribeAuto.copyWith.fieldName(value)` for a single field.
class _$ProfileDescribeAutoCWProxyImpl implements _$ProfileDescribeAutoCWProxy {
  const _$ProfileDescribeAutoCWProxyImpl(this._value);

  final ProfileDescribeAuto _value;

  @override
  ProfileDescribeAuto overwrite(bool? overwrite) => call(overwrite: overwrite);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileDescribeAuto(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileDescribeAuto(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ProfileDescribeAuto call({Object? overwrite = const $CopyWithPlaceholder()}) {
    return ProfileDescribeAuto(
      overwrite: overwrite == const $CopyWithPlaceholder()
          ? _value.overwrite
          // ignore: cast_nullable_to_non_nullable
          : overwrite as bool?,
    );
  }
}

extension $ProfileDescribeAutoCopyWith on ProfileDescribeAuto {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfileDescribeAuto.copyWith(...)` or `instanceOfProfileDescribeAuto.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileDescribeAutoCWProxy get copyWith =>
      _$ProfileDescribeAutoCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileDescribeAuto _$ProfileDescribeAutoFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProfileDescribeAuto', json, ($checkedConvert) {
      final val = ProfileDescribeAuto(
        overwrite: $checkedConvert('overwrite', (v) => v as bool? ?? false),
      );
      return val;
    });

Map<String, dynamic> _$ProfileDescribeAutoToJson(
  ProfileDescribeAuto instance,
) => <String, dynamic>{'overwrite': ?instance.overwrite};
