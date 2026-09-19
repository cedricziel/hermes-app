// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fs_write_text.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$FsWriteTextCWProxy {
  FsWriteText path(String path);

  FsWriteText content(String content);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FsWriteText(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FsWriteText(...).copyWith(id: 12, name: "My name")
  /// ````
  FsWriteText call({String path, String content});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfFsWriteText.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfFsWriteText.copyWith.fieldName(...)`
class _$FsWriteTextCWProxyImpl implements _$FsWriteTextCWProxy {
  const _$FsWriteTextCWProxyImpl(this._value);

  final FsWriteText _value;

  @override
  FsWriteText path(String path) => this(path: path);

  @override
  FsWriteText content(String content) => this(content: content);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `FsWriteText(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// FsWriteText(...).copyWith(id: 12, name: "My name")
  /// ````
  FsWriteText call({
    Object? path = const $CopyWithPlaceholder(),
    Object? content = const $CopyWithPlaceholder(),
  }) {
    return FsWriteText(
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      content: content == const $CopyWithPlaceholder()
          ? _value.content
          // ignore: cast_nullable_to_non_nullable
          : content as String,
    );
  }
}

extension $FsWriteTextCopyWith on FsWriteText {
  /// Returns a callable class that can be used as follows: `instanceOfFsWriteText.copyWith(...)` or like so:`instanceOfFsWriteText.copyWith.fieldName(...)`.
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
