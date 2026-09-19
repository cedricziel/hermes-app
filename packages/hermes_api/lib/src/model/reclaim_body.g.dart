// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reclaim_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReclaimBodyCWProxy {
  ReclaimBody reason(String? reason);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReclaimBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReclaimBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ReclaimBody call({String? reason});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfReclaimBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfReclaimBody.copyWith.fieldName(...)`
class _$ReclaimBodyCWProxyImpl implements _$ReclaimBodyCWProxy {
  const _$ReclaimBodyCWProxyImpl(this._value);

  final ReclaimBody _value;

  @override
  ReclaimBody reason(String? reason) => this(reason: reason);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ReclaimBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ReclaimBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ReclaimBody call({Object? reason = const $CopyWithPlaceholder()}) {
    return ReclaimBody(
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String?,
    );
  }
}

extension $ReclaimBodyCopyWith on ReclaimBody {
  /// Returns a callable class that can be used as follows: `instanceOfReclaimBody.copyWith(...)` or like so:`instanceOfReclaimBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ReclaimBodyCWProxy get copyWith => _$ReclaimBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReclaimBody _$ReclaimBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ReclaimBody', json, ($checkedConvert) {
      final val = ReclaimBody(
        reason: $checkedConvert('reason', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ReclaimBodyToJson(ReclaimBody instance) =>
    <String, dynamic>{'reason': ?instance.reason};
