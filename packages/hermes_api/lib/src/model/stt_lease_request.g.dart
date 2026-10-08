// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stt_lease_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$STTLeaseRequestCWProxy {
  STTLeaseRequest lease(String lease);

  STTLeaseRequest active(bool? active);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `STTLeaseRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// STTLeaseRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  STTLeaseRequest call({String lease, bool? active});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSTTLeaseRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSTTLeaseRequest.copyWith.fieldName(...)`
class _$STTLeaseRequestCWProxyImpl implements _$STTLeaseRequestCWProxy {
  const _$STTLeaseRequestCWProxyImpl(this._value);

  final STTLeaseRequest _value;

  @override
  STTLeaseRequest lease(String lease) => this(lease: lease);

  @override
  STTLeaseRequest active(bool? active) => this(active: active);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `STTLeaseRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// STTLeaseRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  STTLeaseRequest call({
    Object? lease = const $CopyWithPlaceholder(),
    Object? active = const $CopyWithPlaceholder(),
  }) {
    return STTLeaseRequest(
      lease: lease == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfSTTLeaseRequest.copyWith(...)` or like so:`instanceOfSTTLeaseRequest.copyWith.fieldName(...)`.
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
