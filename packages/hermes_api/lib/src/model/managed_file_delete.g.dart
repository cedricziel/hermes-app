// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'managed_file_delete.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ManagedFileDeleteCWProxy {
  ManagedFileDelete path(String path);

  ManagedFileDelete recursive(bool? recursive);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ManagedFileDelete(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ManagedFileDelete(...).copyWith(id: 12, name: "My name")
  /// ```
  ManagedFileDelete call({String path, bool? recursive});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfManagedFileDelete.copyWith(...)` or call `instanceOfManagedFileDelete.copyWith.fieldName(value)` for a single field.
class _$ManagedFileDeleteCWProxyImpl implements _$ManagedFileDeleteCWProxy {
  const _$ManagedFileDeleteCWProxyImpl(this._value);

  final ManagedFileDelete _value;

  @override
  ManagedFileDelete path(String path) => call(path: path);

  @override
  ManagedFileDelete recursive(bool? recursive) => call(recursive: recursive);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ManagedFileDelete(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ManagedFileDelete(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ManagedFileDelete call({
    Object? path = const $CopyWithPlaceholder(),
    Object? recursive = const $CopyWithPlaceholder(),
  }) {
    return ManagedFileDelete(
      path: path == const $CopyWithPlaceholder() || path == null
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      recursive: recursive == const $CopyWithPlaceholder()
          ? _value.recursive
          // ignore: cast_nullable_to_non_nullable
          : recursive as bool?,
    );
  }
}

extension $ManagedFileDeleteCopyWith on ManagedFileDelete {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfManagedFileDelete.copyWith(...)` or `instanceOfManagedFileDelete.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ManagedFileDeleteCWProxy get copyWith =>
      _$ManagedFileDeleteCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ManagedFileDelete _$ManagedFileDeleteFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ManagedFileDelete', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['path']);
      final val = ManagedFileDelete(
        path: $checkedConvert('path', (v) => v as String),
        recursive: $checkedConvert('recursive', (v) => v as bool? ?? false),
      );
      return val;
    });

Map<String, dynamic> _$ManagedFileDeleteToJson(ManagedFileDelete instance) =>
    <String, dynamic>{'path': instance.path, 'recursive': ?instance.recursive};
