// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_provider_config_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemoryProviderConfigUpdateCWProxy {
  MemoryProviderConfigUpdate values(Map<String, Object>? values);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MemoryProviderConfigUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MemoryProviderConfigUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  MemoryProviderConfigUpdate call({Map<String, Object>? values});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMemoryProviderConfigUpdate.copyWith(...)` or call `instanceOfMemoryProviderConfigUpdate.copyWith.fieldName(value)` for a single field.
class _$MemoryProviderConfigUpdateCWProxyImpl
    implements _$MemoryProviderConfigUpdateCWProxy {
  const _$MemoryProviderConfigUpdateCWProxyImpl(this._value);

  final MemoryProviderConfigUpdate _value;

  @override
  MemoryProviderConfigUpdate values(Map<String, Object>? values) =>
      call(values: values);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MemoryProviderConfigUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MemoryProviderConfigUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MemoryProviderConfigUpdate call({
    Object? values = const $CopyWithPlaceholder(),
  }) {
    return MemoryProviderConfigUpdate(
      values: values == const $CopyWithPlaceholder()
          ? _value.values
          // ignore: cast_nullable_to_non_nullable
          : values as Map<String, Object>?,
    );
  }
}

extension $MemoryProviderConfigUpdateCopyWith on MemoryProviderConfigUpdate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMemoryProviderConfigUpdate.copyWith(...)` or `instanceOfMemoryProviderConfigUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemoryProviderConfigUpdateCWProxy get copyWith =>
      _$MemoryProviderConfigUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemoryProviderConfigUpdate _$MemoryProviderConfigUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MemoryProviderConfigUpdate', json, ($checkedConvert) {
  final val = MemoryProviderConfigUpdate(
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

Map<String, dynamic> _$MemoryProviderConfigUpdateToJson(
  MemoryProviderConfigUpdate instance,
) => <String, dynamic>{'values': ?instance.values};
