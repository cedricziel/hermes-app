// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'managed_directory_create.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ManagedDirectoryCreateCWProxy {
  ManagedDirectoryCreate path(String path);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ManagedDirectoryCreate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ManagedDirectoryCreate(...).copyWith(id: 12, name: "My name")
  /// ```
  ManagedDirectoryCreate call({String path});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfManagedDirectoryCreate.copyWith(...)` or call `instanceOfManagedDirectoryCreate.copyWith.fieldName(value)` for a single field.
class _$ManagedDirectoryCreateCWProxyImpl
    implements _$ManagedDirectoryCreateCWProxy {
  const _$ManagedDirectoryCreateCWProxyImpl(this._value);

  final ManagedDirectoryCreate _value;

  @override
  ManagedDirectoryCreate path(String path) => call(path: path);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ManagedDirectoryCreate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ManagedDirectoryCreate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ManagedDirectoryCreate call({Object? path = const $CopyWithPlaceholder()}) {
    return ManagedDirectoryCreate(
      path: path == const $CopyWithPlaceholder() || path == null
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
    );
  }
}

extension $ManagedDirectoryCreateCopyWith on ManagedDirectoryCreate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfManagedDirectoryCreate.copyWith(...)` or `instanceOfManagedDirectoryCreate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ManagedDirectoryCreateCWProxy get copyWith =>
      _$ManagedDirectoryCreateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ManagedDirectoryCreate _$ManagedDirectoryCreateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('ManagedDirectoryCreate', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['path']);
  final val = ManagedDirectoryCreate(
    path: $checkedConvert('path', (v) => v as String),
  );
  return val;
});

Map<String, dynamic> _$ManagedDirectoryCreateToJson(
  ManagedDirectoryCreate instance,
) => <String, dynamic>{'path': instance.path};
