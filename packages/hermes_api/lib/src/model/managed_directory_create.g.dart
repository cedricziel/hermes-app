// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'managed_directory_create.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ManagedDirectoryCreateCWProxy {
  ManagedDirectoryCreate path(String path);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ManagedDirectoryCreate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ManagedDirectoryCreate(...).copyWith(id: 12, name: "My name")
  /// ````
  ManagedDirectoryCreate call({String path});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfManagedDirectoryCreate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfManagedDirectoryCreate.copyWith.fieldName(...)`
class _$ManagedDirectoryCreateCWProxyImpl
    implements _$ManagedDirectoryCreateCWProxy {
  const _$ManagedDirectoryCreateCWProxyImpl(this._value);

  final ManagedDirectoryCreate _value;

  @override
  ManagedDirectoryCreate path(String path) => this(path: path);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ManagedDirectoryCreate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ManagedDirectoryCreate(...).copyWith(id: 12, name: "My name")
  /// ````
  ManagedDirectoryCreate call({Object? path = const $CopyWithPlaceholder()}) {
    return ManagedDirectoryCreate(
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
    );
  }
}

extension $ManagedDirectoryCreateCopyWith on ManagedDirectoryCreate {
  /// Returns a callable class that can be used as follows: `instanceOfManagedDirectoryCreate.copyWith(...)` or like so:`instanceOfManagedDirectoryCreate.copyWith.fieldName(...)`.
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
