// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_provider_setup_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemoryProviderSetupRequestCWProxy {
  MemoryProviderSetupRequest values(Map<String, Object>? values);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemoryProviderSetupRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemoryProviderSetupRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  MemoryProviderSetupRequest call({Map<String, Object>? values});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemoryProviderSetupRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemoryProviderSetupRequest.copyWith.fieldName(...)`
class _$MemoryProviderSetupRequestCWProxyImpl
    implements _$MemoryProviderSetupRequestCWProxy {
  const _$MemoryProviderSetupRequestCWProxyImpl(this._value);

  final MemoryProviderSetupRequest _value;

  @override
  MemoryProviderSetupRequest values(Map<String, Object>? values) =>
      this(values: values);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemoryProviderSetupRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemoryProviderSetupRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  MemoryProviderSetupRequest call({
    Object? values = const $CopyWithPlaceholder(),
  }) {
    return MemoryProviderSetupRequest(
      values: values == const $CopyWithPlaceholder()
          ? _value.values
          // ignore: cast_nullable_to_non_nullable
          : values as Map<String, Object>?,
    );
  }
}

extension $MemoryProviderSetupRequestCopyWith on MemoryProviderSetupRequest {
  /// Returns a callable class that can be used as follows: `instanceOfMemoryProviderSetupRequest.copyWith(...)` or like so:`instanceOfMemoryProviderSetupRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemoryProviderSetupRequestCWProxy get copyWith =>
      _$MemoryProviderSetupRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemoryProviderSetupRequest _$MemoryProviderSetupRequestFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MemoryProviderSetupRequest', json, ($checkedConvert) {
  final val = MemoryProviderSetupRequest(
    values: $checkedConvert(
      'values',
      (v) =>
          (v as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as Object),
          ) ??
          {},
    ),
  );
  return val;
});

Map<String, dynamic> _$MemoryProviderSetupRequestToJson(
  MemoryProviderSetupRequest instance,
) => <String, dynamic>{'values': ?instance.values};
