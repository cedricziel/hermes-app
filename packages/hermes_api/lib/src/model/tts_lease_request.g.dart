// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_lease_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TTSLeaseRequestCWProxy {
  TTSLeaseRequest lease(String lease);

  TTSLeaseRequest active(bool? active);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TTSLeaseRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TTSLeaseRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  TTSLeaseRequest call({String lease, bool? active});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfTTSLeaseRequest.copyWith(...)` or call `instanceOfTTSLeaseRequest.copyWith.fieldName(value)` for a single field.
class _$TTSLeaseRequestCWProxyImpl implements _$TTSLeaseRequestCWProxy {
  const _$TTSLeaseRequestCWProxyImpl(this._value);

  final TTSLeaseRequest _value;

  @override
  TTSLeaseRequest lease(String lease) => call(lease: lease);

  @override
  TTSLeaseRequest active(bool? active) => call(active: active);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `TTSLeaseRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// TTSLeaseRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  TTSLeaseRequest call({
    Object? lease = const $CopyWithPlaceholder(),
    Object? active = const $CopyWithPlaceholder(),
  }) {
    return TTSLeaseRequest(
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

extension $TTSLeaseRequestCopyWith on TTSLeaseRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfTTSLeaseRequest.copyWith(...)` or `instanceOfTTSLeaseRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$TTSLeaseRequestCWProxy get copyWith => _$TTSLeaseRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TTSLeaseRequest _$TTSLeaseRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('TTSLeaseRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['lease']);
      final val = TTSLeaseRequest(
        lease: $checkedConvert('lease', (v) => v as String),
        active: $checkedConvert('active', (v) => v as bool? ?? true),
      );
      return val;
    });

Map<String, dynamic> _$TTSLeaseRequestToJson(TTSLeaseRequest instance) =>
    <String, dynamic>{'lease': instance.lease, 'active': ?instance.active};
