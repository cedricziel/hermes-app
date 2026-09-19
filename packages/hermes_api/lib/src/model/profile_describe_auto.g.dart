// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_describe_auto.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileDescribeAutoCWProxy {
  ProfileDescribeAuto overwrite(bool? overwrite);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileDescribeAuto(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileDescribeAuto(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileDescribeAuto call({bool? overwrite});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfProfileDescribeAuto.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfProfileDescribeAuto.copyWith.fieldName(...)`
class _$ProfileDescribeAutoCWProxyImpl implements _$ProfileDescribeAutoCWProxy {
  const _$ProfileDescribeAutoCWProxyImpl(this._value);

  final ProfileDescribeAuto _value;

  @override
  ProfileDescribeAuto overwrite(bool? overwrite) => this(overwrite: overwrite);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileDescribeAuto(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileDescribeAuto(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfProfileDescribeAuto.copyWith(...)` or like so:`instanceOfProfileDescribeAuto.copyWith.fieldName(...)`.
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
