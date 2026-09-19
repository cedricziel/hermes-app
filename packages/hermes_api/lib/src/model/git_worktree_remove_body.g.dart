// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_worktree_remove_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitWorktreeRemoveBodyCWProxy {
  GitWorktreeRemoveBody path(String path);

  GitWorktreeRemoveBody worktreePath(String worktreePath);

  GitWorktreeRemoveBody force(bool? force);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitWorktreeRemoveBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitWorktreeRemoveBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitWorktreeRemoveBody call({String path, String worktreePath, bool? force});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGitWorktreeRemoveBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGitWorktreeRemoveBody.copyWith.fieldName(...)`
class _$GitWorktreeRemoveBodyCWProxyImpl
    implements _$GitWorktreeRemoveBodyCWProxy {
  const _$GitWorktreeRemoveBodyCWProxyImpl(this._value);

  final GitWorktreeRemoveBody _value;

  @override
  GitWorktreeRemoveBody path(String path) => this(path: path);

  @override
  GitWorktreeRemoveBody worktreePath(String worktreePath) =>
      this(worktreePath: worktreePath);

  @override
  GitWorktreeRemoveBody force(bool? force) => this(force: force);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitWorktreeRemoveBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitWorktreeRemoveBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitWorktreeRemoveBody call({
    Object? path = const $CopyWithPlaceholder(),
    Object? worktreePath = const $CopyWithPlaceholder(),
    Object? force = const $CopyWithPlaceholder(),
  }) {
    return GitWorktreeRemoveBody(
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      worktreePath: worktreePath == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfGitWorktreeRemoveBody.copyWith(...)` or like so:`instanceOfGitWorktreeRemoveBody.copyWith.fieldName(...)`.
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
