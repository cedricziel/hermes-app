// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'memory_reset.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$MemoryResetCWProxy {
  MemoryReset target(String? target);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MemoryReset(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MemoryReset(...).copyWith(id: 12, name: "My name")
  /// ```
  MemoryReset call({String? target});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfMemoryReset.copyWith(...)` or call `instanceOfMemoryReset.copyWith.fieldName(value)` for a single field.
class _$MemoryResetCWProxyImpl implements _$MemoryResetCWProxy {
  const _$MemoryResetCWProxyImpl(this._value);

  final MemoryReset _value;

  @override
  MemoryReset target(String? target) => call(target: target);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `MemoryReset(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// MemoryReset(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfMemoryReset.copyWith(...)` or `instanceOfMemoryReset.copyWith.fieldName(...)`.
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
