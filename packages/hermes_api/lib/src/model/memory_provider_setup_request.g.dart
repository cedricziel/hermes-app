// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_provider_setup_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemoryProviderSetupRequestCWProxy {
  MemoryProviderSetupRequest values(Map<String, Object>? values);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MemoryProviderSetupRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MemoryProviderSetupRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  MemoryProviderSetupRequest call({Map<String, Object>? values});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMemoryProviderSetupRequest.copyWith(...)` or call `instanceOfMemoryProviderSetupRequest.copyWith.fieldName(value)` for a single field.
class _$MemoryProviderSetupRequestCWProxyImpl
    implements _$MemoryProviderSetupRequestCWProxy {
  const _$MemoryProviderSetupRequestCWProxyImpl(this._value);

  final MemoryProviderSetupRequest _value;

  @override
  MemoryProviderSetupRequest values(Map<String, Object>? values) =>
      call(values: values);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MemoryProviderSetupRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MemoryProviderSetupRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMemoryProviderSetupRequest.copyWith(...)` or `instanceOfMemoryProviderSetupRequest.copyWith.fieldName(...)`.
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
