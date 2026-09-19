// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_provider_select.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemoryProviderSelectCWProxy {
  MemoryProviderSelect provider(String provider);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemoryProviderSelect(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemoryProviderSelect(...).copyWith(id: 12, name: "My name")
  /// ````
  MemoryProviderSelect call({String provider});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemoryProviderSelect.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemoryProviderSelect.copyWith.fieldName(...)`
class _$MemoryProviderSelectCWProxyImpl
    implements _$MemoryProviderSelectCWProxy {
  const _$MemoryProviderSelectCWProxyImpl(this._value);

  final MemoryProviderSelect _value;

  @override
  MemoryProviderSelect provider(String provider) => this(provider: provider);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemoryProviderSelect(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemoryProviderSelect(...).copyWith(id: 12, name: "My name")
  /// ````
  MemoryProviderSelect call({Object? provider = const $CopyWithPlaceholder()}) {
    return MemoryProviderSelect(
      provider: provider == const $CopyWithPlaceholder()
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String,
    );
  }
}

extension $MemoryProviderSelectCopyWith on MemoryProviderSelect {
  /// Returns a callable class that can be used as follows: `instanceOfMemoryProviderSelect.copyWith(...)` or like so:`instanceOfMemoryProviderSelect.copyWith.fieldName(...)`.
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
