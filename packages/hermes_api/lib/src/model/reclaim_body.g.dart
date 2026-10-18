// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reclaim_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ReclaimBodyCWProxy {
  ReclaimBody reason(String? reason);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ReclaimBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ReclaimBody(...).copyWith(id: 12, name: "My name")
  /// ```
  ReclaimBody call({String? reason});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfReclaimBody.copyWith(...)` or call `instanceOfReclaimBody.copyWith.fieldName(value)` for a single field.
class _$ReclaimBodyCWProxyImpl implements _$ReclaimBodyCWProxy {
  const _$ReclaimBodyCWProxyImpl(this._value);

  final ReclaimBody _value;

  @override
  ReclaimBody reason(String? reason) => call(reason: reason);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ReclaimBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ReclaimBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfReclaimBody.copyWith(...)` or `instanceOfReclaimBody.copyWith.fieldName(...)`.
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
