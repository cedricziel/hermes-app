// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_file_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitFileBodyCWProxy {
  GitFileBody path(String path);

  GitFileBody file(String? file);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitFileBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitFileBody(...).copyWith(id: 12, name: "My name")
  /// ```
  GitFileBody call({String path, String? file});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfGitFileBody.copyWith(...)` or call `instanceOfGitFileBody.copyWith.fieldName(value)` for a single field.
class _$GitFileBodyCWProxyImpl implements _$GitFileBodyCWProxy {
  const _$GitFileBodyCWProxyImpl(this._value);

  final GitFileBody _value;

  @override
  GitFileBody path(String path) => call(path: path);

  @override
  GitFileBody file(String? file) => call(file: file);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitFileBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitFileBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  GitFileBody call({
    Object? path = const $CopyWithPlaceholder(),
    Object? file = const $CopyWithPlaceholder(),
  }) {
    return GitFileBody(
      path: path == const $CopyWithPlaceholder() || path == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfGitFileBody.copyWith(...)` or `instanceOfGitFileBody.copyWith.fieldName(...)`.
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
