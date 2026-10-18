// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fs_write_text.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FsWriteTextCWProxy {
  FsWriteText path(String path);

  FsWriteText content(String content);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `FsWriteText(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// FsWriteText(...).copyWith(id: 12, name: "My name")
  /// ```
  FsWriteText call({String path, String content});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfFsWriteText.copyWith(...)` or call `instanceOfFsWriteText.copyWith.fieldName(value)` for a single field.
class _$FsWriteTextCWProxyImpl implements _$FsWriteTextCWProxy {
  const _$FsWriteTextCWProxyImpl(this._value);

  final FsWriteText _value;

  @override
  FsWriteText path(String path) => call(path: path);

  @override
  FsWriteText content(String content) => call(content: content);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `FsWriteText(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// FsWriteText(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  FsWriteText call({
    Object? path = const $CopyWithPlaceholder(),
    Object? content = const $CopyWithPlaceholder(),
  }) {
    return FsWriteText(
      path: path == const $CopyWithPlaceholder() || path == null
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      content: content == const $CopyWithPlaceholder() || content == null
          ? _value.content
          // ignore: cast_nullable_to_non_nullable
          : content as String,
    );
  }
}

extension $FsWriteTextCopyWith on FsWriteText {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfFsWriteText.copyWith(...)` or `instanceOfFsWriteText.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$FsWriteTextCWProxy get copyWith => _$FsWriteTextCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FsWriteText _$FsWriteTextFromJson(Map<String, dynamic> json) =>
    $checkedCreate('FsWriteText', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['path', 'content']);
      final val = FsWriteText(
        path: $checkedConvert('path', (v) => v as String),
        content: $checkedConvert('content', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$FsWriteTextToJson(FsWriteText instance) =>
    <String, dynamic>{'path': instance.path, 'content': instance.content};
