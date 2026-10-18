// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stt_lease_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$STTLeaseRequestCWProxy {
  STTLeaseRequest lease(String lease);

  STTLeaseRequest active(bool? active);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `STTLeaseRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// STTLeaseRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  STTLeaseRequest call({String lease, bool? active});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfSTTLeaseRequest.copyWith(...)` or call `instanceOfSTTLeaseRequest.copyWith.fieldName(value)` for a single field.
class _$STTLeaseRequestCWProxyImpl implements _$STTLeaseRequestCWProxy {
  const _$STTLeaseRequestCWProxyImpl(this._value);

  final STTLeaseRequest _value;

  @override
  STTLeaseRequest lease(String lease) => call(lease: lease);

  @override
  STTLeaseRequest active(bool? active) => call(active: active);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `STTLeaseRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// STTLeaseRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  STTLeaseRequest call({
    Object? lease = const $CopyWithPlaceholder(),
    Object? active = const $CopyWithPlaceholder(),
  }) {
    return STTLeaseRequest(
      lease: lease == const $CopyWithPlaceholder() || lease == null
          ? _value.lease
          // ignore: cast_nullable_to_non_nullable
          : lease as String,
      active: active == const $CopyWithPlaceholder()
          ? _value.active
          // ignore: cast_nullable_to_non_nullable
          : active as bool?,
    );
  }
}

extension $STTLeaseRequestCopyWith on STTLeaseRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfSTTLeaseRequest.copyWith(...)` or `instanceOfSTTLeaseRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$STTLeaseRequestCWProxy get copyWith => _$STTLeaseRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

STTLeaseRequest _$STTLeaseRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('STTLeaseRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['lease']);
      final val = STTLeaseRequest(
        lease: $checkedConvert('lease', (v) => v as String),
        active: $checkedConvert('active', (v) => v as bool? ?? true),
      );
      return val;
    });

Map<String, dynamic> _$STTLeaseRequestToJson(STTLeaseRequest instance) =>
    <String, dynamic>{'lease': instance.lease, 'active': ?instance.active};
