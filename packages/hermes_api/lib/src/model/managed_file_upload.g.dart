// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'managed_file_upload.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ManagedFileUploadCWProxy {
  ManagedFileUpload path(String path);

  ManagedFileUpload dataUrl(String dataUrl);

  ManagedFileUpload overwrite(bool? overwrite);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ManagedFileUpload(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ManagedFileUpload(...).copyWith(id: 12, name: "My name")
  /// ````
  ManagedFileUpload call({String path, String dataUrl, bool? overwrite});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfManagedFileUpload.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfManagedFileUpload.copyWith.fieldName(...)`
class _$ManagedFileUploadCWProxyImpl implements _$ManagedFileUploadCWProxy {
  const _$ManagedFileUploadCWProxyImpl(this._value);

  final ManagedFileUpload _value;

  @override
  ManagedFileUpload path(String path) => this(path: path);

  @override
  ManagedFileUpload dataUrl(String dataUrl) => this(dataUrl: dataUrl);

  @override
  ManagedFileUpload overwrite(bool? overwrite) => this(overwrite: overwrite);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ManagedFileUpload(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ManagedFileUpload(...).copyWith(id: 12, name: "My name")
  /// ````
  ManagedFileUpload call({
    Object? path = const $CopyWithPlaceholder(),
    Object? dataUrl = const $CopyWithPlaceholder(),
    Object? overwrite = const $CopyWithPlaceholder(),
  }) {
    return ManagedFileUpload(
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      dataUrl: dataUrl == const $CopyWithPlaceholder()
          ? _value.dataUrl
          // ignore: cast_nullable_to_non_nullable
          : dataUrl as String,
      overwrite: overwrite == const $CopyWithPlaceholder()
          ? _value.overwrite
          // ignore: cast_nullable_to_non_nullable
          : overwrite as bool?,
    );
  }
}

extension $ManagedFileUploadCopyWith on ManagedFileUpload {
  /// Returns a callable class that can be used as follows: `instanceOfManagedFileUpload.copyWith(...)` or like so:`instanceOfManagedFileUpload.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ManagedFileUploadCWProxy get copyWith =>
      _$ManagedFileUploadCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ManagedFileUpload _$ManagedFileUploadFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ManagedFileUpload', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['path', 'data_url']);
      final val = ManagedFileUpload(
        path: $checkedConvert('path', (v) => v as String),
        dataUrl: $checkedConvert('data_url', (v) => v as String),
        overwrite: $checkedConvert('overwrite', (v) => v as bool? ?? true),
      );
      return val;
    }, fieldKeyMap: const {'dataUrl': 'data_url'});

Map<String, dynamic> _$ManagedFileUploadToJson(ManagedFileUpload instance) =>
    <String, dynamic>{
      'path': instance.path,
      'data_url': instance.dataUrl,
      'overwrite': ?instance.overwrite,
    };
