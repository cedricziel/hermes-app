// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'terminate_run_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TerminateRunBodyCWProxy {
  TerminateRunBody reason(String? reason);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TerminateRunBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TerminateRunBody(...).copyWith(id: 12, name: "My name")
  /// ```
  TerminateRunBody call({String? reason});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTerminateRunBody.copyWith(...)` or call `instanceOfTerminateRunBody.copyWith.fieldName(value)` for a single field.
class _$TerminateRunBodyCWProxyImpl implements _$TerminateRunBodyCWProxy {
  const _$TerminateRunBodyCWProxyImpl(this._value);

  final TerminateRunBody _value;

  @override
  TerminateRunBody reason(String? reason) => call(reason: reason);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TerminateRunBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TerminateRunBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  TerminateRunBody call({Object? reason = const $CopyWithPlaceholder()}) {
    return TerminateRunBody(
      reason: reason == const $CopyWithPlaceholder()
          ? _value.reason
          // ignore: cast_nullable_to_non_nullable
          : reason as String?,
    );
  }
}

extension $TerminateRunBodyCopyWith on TerminateRunBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTerminateRunBody.copyWith(...)` or `instanceOfTerminateRunBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TerminateRunBodyCWProxy get copyWith => _$TerminateRunBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TerminateRunBody _$TerminateRunBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TerminateRunBody', json, ($checkedConvert) {
      final val = TerminateRunBody(
        reason: $checkedConvert('reason', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$TerminateRunBodyToJson(TerminateRunBody instance) =>
    <String, dynamic>{'reason': ?instance.reason};
