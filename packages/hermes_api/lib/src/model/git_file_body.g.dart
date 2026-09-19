// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_file_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitFileBodyCWProxy {
  GitFileBody path(String path);

  GitFileBody file(String? file);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitFileBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitFileBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitFileBody call({String path, String? file});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGitFileBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGitFileBody.copyWith.fieldName(...)`
class _$GitFileBodyCWProxyImpl implements _$GitFileBodyCWProxy {
  const _$GitFileBodyCWProxyImpl(this._value);

  final GitFileBody _value;

  @override
  GitFileBody path(String path) => this(path: path);

  @override
  GitFileBody file(String? file) => this(file: file);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitFileBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitFileBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitFileBody call({
    Object? path = const $CopyWithPlaceholder(),
    Object? file = const $CopyWithPlaceholder(),
  }) {
    return GitFileBody(
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      file: file == const $CopyWithPlaceholder()
          ? _value.file
          // ignore: cast_nullable_to_non_nullable
          : file as String?,
    );
  }
}

extension $GitFileBodyCopyWith on GitFileBody {
  /// Returns a callable class that can be used as follows: `instanceOfGitFileBody.copyWith(...)` or like so:`instanceOfGitFileBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GitFileBodyCWProxy get copyWith => _$GitFileBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitFileBody _$GitFileBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GitFileBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['path']);
      final val = GitFileBody(
        path: $checkedConvert('path', (v) => v as String),
        file: $checkedConvert('file', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$GitFileBodyToJson(GitFileBody instance) =>
    <String, dynamic>{'path': instance.path, 'file': ?instance.file};
