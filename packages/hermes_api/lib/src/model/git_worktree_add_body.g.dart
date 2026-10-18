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

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitWorktreeAddBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitWorktreeAddBody(...).copyWith(id: 12, name: "My name")
  /// ```
  GitWorktreeAddBody call({
    String path,
    String? name,
    String? branch,
    String? base_,
    String? existingBranch,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfGitWorktreeAddBody.copyWith(...)` or call `instanceOfGitWorktreeAddBody.copyWith.fieldName(value)` for a single field.
class _$GitWorktreeAddBodyCWProxyImpl implements _$GitWorktreeAddBodyCWProxy {
  const _$GitWorktreeAddBodyCWProxyImpl(this._value);

  final GitWorktreeAddBody _value;

  @override
  GitWorktreeAddBody path(String path) => call(path: path);

  @override
  GitWorktreeAddBody name(String? name) => call(name: name);

  @override
  GitWorktreeAddBody branch(String? branch) => call(branch: branch);

  @override
  GitWorktreeAddBody base_(String? base_) => call(base_: base_);

  @override
  GitWorktreeAddBody existingBranch(String? existingBranch) =>
      call(existingBranch: existingBranch);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitWorktreeAddBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitWorktreeAddBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  GitWorktreeAddBody call({
    Object? path = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? branch = const $CopyWithPlaceholder(),
    Object? base_ = const $CopyWithPlaceholder(),
    Object? existingBranch = const $CopyWithPlaceholder(),
  }) {
    return GitWorktreeAddBody(
      path: path == const $CopyWithPlaceholder() || path == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfGitWorktreeAddBody.copyWith(...)` or `instanceOfGitWorktreeAddBody.copyWith.fieldName(...)`.
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
