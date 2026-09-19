// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tts_lease_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$TTSLeaseRequestCWProxy {
  TTSLeaseRequest lease(String lease);

  TTSLeaseRequest active(bool? active);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TTSLeaseRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TTSLeaseRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  TTSLeaseRequest call({String lease, bool? active});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfTTSLeaseRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfTTSLeaseRequest.copyWith.fieldName(...)`
class _$TTSLeaseRequestCWProxyImpl implements _$TTSLeaseRequestCWProxy {
  const _$TTSLeaseRequestCWProxyImpl(this._value);

  final TTSLeaseRequest _value;

  @override
  TTSLeaseRequest lease(String lease) => this(lease: lease);

  @override
  TTSLeaseRequest active(bool? active) => this(active: active);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `TTSLeaseRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// TTSLeaseRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  TTSLeaseRequest call({
    Object? lease = const $CopyWithPlaceholder(),
    Object? active = const $CopyWithPlaceholder(),
  }) {
    return TTSLeaseRequest(
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

extension $TTSLeaseRequestCopyWith on TTSLeaseRequest {
  /// Returns a callable class that can be used as follows: `instanceOfTTSLeaseRequest.copyWith(...)` or like so:`instanceOfTTSLeaseRequest.copyWith.fieldName(...)`.
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
