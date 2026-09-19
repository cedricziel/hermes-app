// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_provider_config_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemoryProviderConfigUpdateCWProxy {
  MemoryProviderConfigUpdate values(Map<String, Object>? values);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemoryProviderConfigUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemoryProviderConfigUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  MemoryProviderConfigUpdate call({Map<String, Object>? values});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemoryProviderConfigUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemoryProviderConfigUpdate.copyWith.fieldName(...)`
class _$MemoryProviderConfigUpdateCWProxyImpl
    implements _$MemoryProviderConfigUpdateCWProxy {
  const _$MemoryProviderConfigUpdateCWProxyImpl(this._value);

  final MemoryProviderConfigUpdate _value;

  @override
  MemoryProviderConfigUpdate values(Map<String, Object>? values) =>
      this(values: values);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemoryProviderConfigUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemoryProviderConfigUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfMemoryProviderConfigUpdate.copyWith(...)` or like so:`instanceOfMemoryProviderConfigUpdate.copyWith.fieldName(...)`.
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
