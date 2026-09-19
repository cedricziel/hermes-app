// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_reset.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemoryResetCWProxy {
  MemoryReset target(String? target);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemoryReset(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemoryReset(...).copyWith(id: 12, name: "My name")
  /// ````
  MemoryReset call({String? target});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfMemoryReset.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfMemoryReset.copyWith.fieldName(...)`
class _$MemoryResetCWProxyImpl implements _$MemoryResetCWProxy {
  const _$MemoryResetCWProxyImpl(this._value);

  final MemoryReset _value;

  @override
  MemoryReset target(String? target) => this(target: target);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `MemoryReset(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// MemoryReset(...).copyWith(id: 12, name: "My name")
  /// ````
  MemoryReset call({Object? target = const $CopyWithPlaceholder()}) {
    return MemoryReset(
      target: target == const $CopyWithPlaceholder()
          ? _value.target
          // ignore: cast_nullable_to_non_nullable
          : target as String?,
    );
  }
}

extension $MemoryResetCopyWith on MemoryReset {
  /// Returns a callable class that can be used as follows: `instanceOfMemoryReset.copyWith(...)` or like so:`instanceOfMemoryReset.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$MemoryResetCWProxy get copyWith => _$MemoryResetCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MemoryReset _$MemoryResetFromJson(Map<String, dynamic> json) =>
    $checkedCreate('MemoryReset', json, ($checkedConvert) {
      final val = MemoryReset(
        target: $checkedConvert('target', (v) => v as String? ?? 'all'),
      );
      return val;
    });

Map<String, dynamic> _$MemoryResetToJson(MemoryReset instance) =>
    <String, dynamic>{'target': ?instance.target};
