// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'managed_file_upload.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ManagedFileUploadCWProxy {
  ManagedFileUpload path(String path);

  ManagedFileUpload dataUrl(String dataUrl);

  ManagedFileUpload overwrite(bool? overwrite);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ManagedFileUpload(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ManagedFileUpload(...).copyWith(id: 12, name: "My name")
  /// ```
  ManagedFileUpload call({String path, String dataUrl, bool? overwrite});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfManagedFileUpload.copyWith(...)` or call `instanceOfManagedFileUpload.copyWith.fieldName(value)` for a single field.
class _$ManagedFileUploadCWProxyImpl implements _$ManagedFileUploadCWProxy {
  const _$ManagedFileUploadCWProxyImpl(this._value);

  final ManagedFileUpload _value;

  @override
  ManagedFileUpload path(String path) => call(path: path);

  @override
  ManagedFileUpload dataUrl(String dataUrl) => call(dataUrl: dataUrl);

  @override
  ManagedFileUpload overwrite(bool? overwrite) => call(overwrite: overwrite);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ManagedFileUpload(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ManagedFileUpload(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ManagedFileUpload call({
    Object? path = const $CopyWithPlaceholder(),
    Object? dataUrl = const $CopyWithPlaceholder(),
    Object? overwrite = const $CopyWithPlaceholder(),
  }) {
    return ManagedFileUpload(
      path: path == const $CopyWithPlaceholder() || path == null
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      dataUrl: dataUrl == const $CopyWithPlaceholder() || dataUrl == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfManagedFileUpload.copyWith(...)` or `instanceOfManagedFileUpload.copyWith.fieldName(...)`.
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
