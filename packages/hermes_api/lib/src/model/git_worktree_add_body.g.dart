// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_worktree_add_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitWorktreeAddBodyCWProxy {
  GitWorktreeAddBody path(String path);

  GitWorktreeAddBody name(String? name);

  GitWorktreeAddBody branch(String? branch);

  GitWorktreeAddBody base_(String? base_);

  GitWorktreeAddBody existingBranch(String? existingBranch);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitWorktreeAddBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitWorktreeAddBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitWorktreeAddBody call({
    String path,
    String? name,
    String? branch,
    String? base_,
    String? existingBranch,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGitWorktreeAddBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGitWorktreeAddBody.copyWith.fieldName(...)`
class _$GitWorktreeAddBodyCWProxyImpl implements _$GitWorktreeAddBodyCWProxy {
  const _$GitWorktreeAddBodyCWProxyImpl(this._value);

  final GitWorktreeAddBody _value;

  @override
  GitWorktreeAddBody path(String path) => this(path: path);

  @override
  GitWorktreeAddBody name(String? name) => this(name: name);

  @override
  GitWorktreeAddBody branch(String? branch) => this(branch: branch);

  @override
  GitWorktreeAddBody base_(String? base_) => this(base_: base_);

  @override
  GitWorktreeAddBody existingBranch(String? existingBranch) =>
      this(existingBranch: existingBranch);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitWorktreeAddBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitWorktreeAddBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitWorktreeAddBody call({
    Object? path = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? branch = const $CopyWithPlaceholder(),
    Object? base_ = const $CopyWithPlaceholder(),
    Object? existingBranch = const $CopyWithPlaceholder(),
  }) {
    return GitWorktreeAddBody(
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String?,
      branch: branch == const $CopyWithPlaceholder()
          ? _value.branch
          // ignore: cast_nullable_to_non_nullable
          : branch as String?,
      base_: base_ == const $CopyWithPlaceholder()
          ? _value.base_
          // ignore: cast_nullable_to_non_nullable
          : base_ as String?,
      existingBranch: existingBranch == const $CopyWithPlaceholder()
          ? _value.existingBranch
          // ignore: cast_nullable_to_non_nullable
          : existingBranch as String?,
    );
  }
}

extension $GitWorktreeAddBodyCopyWith on GitWorktreeAddBody {
  /// Returns a callable class that can be used as follows: `instanceOfGitWorktreeAddBody.copyWith(...)` or like so:`instanceOfGitWorktreeAddBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GitWorktreeAddBodyCWProxy get copyWith =>
      _$GitWorktreeAddBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitWorktreeAddBody _$GitWorktreeAddBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GitWorktreeAddBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['path']);
      final val = GitWorktreeAddBody(
        path: $checkedConvert('path', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String?),
        branch: $checkedConvert('branch', (v) => v as String?),
        base_: $checkedConvert('base', (v) => v as String?),
        existingBranch: $checkedConvert('existingBranch', (v) => v as String?),
      );
      return val;
    }, fieldKeyMap: const {'base_': 'base'});

Map<String, dynamic> _$GitWorktreeAddBodyToJson(GitWorktreeAddBody instance) =>
    <String, dynamic>{
      'path': instance.path,
      'name': ?instance.name,
      'branch': ?instance.branch,
      'base': ?instance.base_,
      'existingBranch': ?instance.existingBranch,
    };
