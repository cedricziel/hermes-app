// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_path_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitPathBodyCWProxy {
  GitPathBody path(String path);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitPathBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitPathBody(...).copyWith(id: 12, name: "My name")
  /// ```
  GitPathBody call({String path});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfGitPathBody.copyWith(...)` or call `instanceOfGitPathBody.copyWith.fieldName(value)` for a single field.
class _$GitPathBodyCWProxyImpl implements _$GitPathBodyCWProxy {
  const _$GitPathBodyCWProxyImpl(this._value);

  final GitPathBody _value;

  @override
  GitPathBody path(String path) => call(path: path);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitPathBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitPathBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  GitPathBody call({Object? path = const $CopyWithPlaceholder()}) {
    return GitPathBody(
      path: path == const $CopyWithPlaceholder() || path == null
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
    );
  }
}

extension $GitPathBodyCopyWith on GitPathBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfGitPathBody.copyWith(...)` or `instanceOfGitPathBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GitPathBodyCWProxy get copyWith => _$GitPathBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitPathBody _$GitPathBodyFromJson(Map<String, dynamic> json) => $checkedCreate(
  'GitPathBody',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['path']);
    final val = GitPathBody(path: $checkedConvert('path', (v) => v as String));
    return val;
  },
);

Map<String, dynamic> _$GitPathBodyToJson(GitPathBody instance) =>
    <String, dynamic>{'path': instance.path};
