// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_commit_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitCommitBodyCWProxy {
  GitCommitBody path(String path);

  GitCommitBody message(String message);

  GitCommitBody push(bool? push);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitCommitBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitCommitBody(...).copyWith(id: 12, name: "My name")
  /// ```
  GitCommitBody call({String path, String message, bool? push});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfGitCommitBody.copyWith(...)` or call `instanceOfGitCommitBody.copyWith.fieldName(value)` for a single field.
class _$GitCommitBodyCWProxyImpl implements _$GitCommitBodyCWProxy {
  const _$GitCommitBodyCWProxyImpl(this._value);

  final GitCommitBody _value;

  @override
  GitCommitBody path(String path) => call(path: path);

  @override
  GitCommitBody message(String message) => call(message: message);

  @override
  GitCommitBody push(bool? push) => call(push: push);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitCommitBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitCommitBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  GitCommitBody call({
    Object? path = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
    Object? push = const $CopyWithPlaceholder(),
  }) {
    return GitCommitBody(
      path: path == const $CopyWithPlaceholder() || path == null
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      message: message == const $CopyWithPlaceholder() || message == null
          ? _value.message
          // ignore: cast_nullable_to_non_nullable
          : message as String,
      push: push == const $CopyWithPlaceholder()
          ? _value.push
          // ignore: cast_nullable_to_non_nullable
          : push as bool?,
    );
  }
}

extension $GitCommitBodyCopyWith on GitCommitBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfGitCommitBody.copyWith(...)` or `instanceOfGitCommitBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GitCommitBodyCWProxy get copyWith => _$GitCommitBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitCommitBody _$GitCommitBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GitCommitBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['path', 'message']);
      final val = GitCommitBody(
        path: $checkedConvert('path', (v) => v as String),
        message: $checkedConvert('message', (v) => v as String),
        push: $checkedConvert('push', (v) => v as bool? ?? false),
      );
      return val;
    });

Map<String, dynamic> _$GitCommitBodyToJson(GitCommitBody instance) =>
    <String, dynamic>{
      'path': instance.path,
      'message': instance.message,
      'push': ?instance.push,
    };
