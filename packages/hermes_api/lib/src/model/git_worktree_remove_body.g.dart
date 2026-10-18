// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_worktree_remove_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitWorktreeRemoveBodyCWProxy {
  GitWorktreeRemoveBody path(String path);

  GitWorktreeRemoveBody worktreePath(String worktreePath);

  GitWorktreeRemoveBody force(bool? force);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitWorktreeRemoveBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitWorktreeRemoveBody(...).copyWith(id: 12, name: "My name")
  /// ```
  GitWorktreeRemoveBody call({String path, String worktreePath, bool? force});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfGitWorktreeRemoveBody.copyWith(...)` or call `instanceOfGitWorktreeRemoveBody.copyWith.fieldName(value)` for a single field.
class _$GitWorktreeRemoveBodyCWProxyImpl
    implements _$GitWorktreeRemoveBodyCWProxy {
  const _$GitWorktreeRemoveBodyCWProxyImpl(this._value);

  final GitWorktreeRemoveBody _value;

  @override
  GitWorktreeRemoveBody path(String path) => call(path: path);

  @override
  GitWorktreeRemoveBody worktreePath(String worktreePath) =>
      call(worktreePath: worktreePath);

  @override
  GitWorktreeRemoveBody force(bool? force) => call(force: force);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitWorktreeRemoveBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitWorktreeRemoveBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  GitWorktreeRemoveBody call({
    Object? path = const $CopyWithPlaceholder(),
    Object? worktreePath = const $CopyWithPlaceholder(),
    Object? force = const $CopyWithPlaceholder(),
  }) {
    return GitWorktreeRemoveBody(
      path: path == const $CopyWithPlaceholder() || path == null
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      worktreePath:
          worktreePath == const $CopyWithPlaceholder() || worktreePath == null
          ? _value.worktreePath
          // ignore: cast_nullable_to_non_nullable
          : worktreePath as String,
      force: force == const $CopyWithPlaceholder()
          ? _value.force
          // ignore: cast_nullable_to_non_nullable
          : force as bool?,
    );
  }
}

extension $GitWorktreeRemoveBodyCopyWith on GitWorktreeRemoveBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfGitWorktreeRemoveBody.copyWith(...)` or `instanceOfGitWorktreeRemoveBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GitWorktreeRemoveBodyCWProxy get copyWith =>
      _$GitWorktreeRemoveBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitWorktreeRemoveBody _$GitWorktreeRemoveBodyFromJson(
  Map<String, dynamic> json,
) => $checkedCreate('GitWorktreeRemoveBody', json, ($checkedConvert) {
  $checkKeys(json, requiredKeys: const ['path', 'worktreePath']);
  final val = GitWorktreeRemoveBody(
    path: $checkedConvert('path', (v) => v as String),
    worktreePath: $checkedConvert('worktreePath', (v) => v as String),
    force: $checkedConvert('force', (v) => v as bool? ?? false),
  );
  return val;
});

Map<String, dynamic> _$GitWorktreeRemoveBodyToJson(
  GitWorktreeRemoveBody instance,
) => <String, dynamic>{
  'path': instance.path,
  'worktreePath': instance.worktreePath,
  'force': ?instance.force,
};
