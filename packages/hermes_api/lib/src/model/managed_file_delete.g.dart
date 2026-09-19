// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'managed_file_delete.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ManagedFileDeleteCWProxy {
  ManagedFileDelete path(String path);

  ManagedFileDelete recursive(bool? recursive);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ManagedFileDelete(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ManagedFileDelete(...).copyWith(id: 12, name: "My name")
  /// ````
  ManagedFileDelete call({String path, bool? recursive});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfManagedFileDelete.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfManagedFileDelete.copyWith.fieldName(...)`
class _$ManagedFileDeleteCWProxyImpl implements _$ManagedFileDeleteCWProxy {
  const _$ManagedFileDeleteCWProxyImpl(this._value);

  final ManagedFileDelete _value;

  @override
  ManagedFileDelete path(String path) => this(path: path);

  @override
  ManagedFileDelete recursive(bool? recursive) => this(recursive: recursive);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ManagedFileDelete(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ManagedFileDelete(...).copyWith(id: 12, name: "My name")
  /// ````
  ManagedFileDelete call({
    Object? path = const $CopyWithPlaceholder(),
    Object? recursive = const $CopyWithPlaceholder(),
  }) {
    return ManagedFileDelete(
      path: path == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfManagedFileDelete.copyWith(...)` or like so:`instanceOfManagedFileDelete.copyWith.fieldName(...)`.
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
