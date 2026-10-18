// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_provider_select.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemoryProviderSelectCWProxy {
  MemoryProviderSelect provider(String provider);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MemoryProviderSelect(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MemoryProviderSelect(...).copyWith(id: 12, name: "My name")
  /// ```
  MemoryProviderSelect call({String provider});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMemoryProviderSelect.copyWith(...)` or call `instanceOfMemoryProviderSelect.copyWith.fieldName(value)` for a single field.
class _$MemoryProviderSelectCWProxyImpl
    implements _$MemoryProviderSelectCWProxy {
  const _$MemoryProviderSelectCWProxyImpl(this._value);

  final MemoryProviderSelect _value;

  @override
  MemoryProviderSelect provider(String provider) => call(provider: provider);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MemoryProviderSelect(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MemoryProviderSelect(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  MemoryProviderSelect call({Object? provider = const $CopyWithPlaceholder()}) {
    return MemoryProviderSelect(
      provider: provider == const $CopyWithPlaceholder() || provider == null
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String,
    );
  }
}

extension $MemoryProviderSelectCopyWith on MemoryProviderSelect {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMemoryProviderSelect.copyWith(...)` or `instanceOfMemoryProviderSelect.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemoryProviderSelectCWProxy get copyWith =>
      _$MemoryProviderSelectCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemoryProviderSelect _$MemoryProviderSelectFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('MemoryProviderSelect', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['provider']);
  final val = MemoryProviderSelect(
    provider: $checkedConvert('provider', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$MemoryProviderSelectToJson(
  MemoryProviderSelect instance,
) => <String, dynamic>{'provider': instance.provider};
