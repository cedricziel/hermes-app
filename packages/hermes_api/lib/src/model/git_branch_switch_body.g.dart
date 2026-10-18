// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_branch_switch_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitBranchSwitchBodyCWProxy {
  GitBranchSwitchBody path(String path);

  GitBranchSwitchBody branch(String branch);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitBranchSwitchBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitBranchSwitchBody(...).copyWith(id: 12, name: "My name")
  /// ```
  GitBranchSwitchBody call({String path, String branch});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfGitBranchSwitchBody.copyWith(...)` or call `instanceOfGitBranchSwitchBody.copyWith.fieldName(value)` for a single field.
class _$GitBranchSwitchBodyCWProxyImpl implements _$GitBranchSwitchBodyCWProxy {
  const _$GitBranchSwitchBodyCWProxyImpl(this._value);

  final GitBranchSwitchBody _value;

  @override
  GitBranchSwitchBody path(String path) => call(path: path);

  @override
  GitBranchSwitchBody branch(String branch) => call(branch: branch);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitBranchSwitchBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitBranchSwitchBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  GitBranchSwitchBody call({
    Object? path = const $CopyWithPlaceholder(),
    Object? branch = const $CopyWithPlaceholder(),
  }) {
    return GitBranchSwitchBody(
      path: path == const $CopyWithPlaceholder() || path == null
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      branch: branch == const $CopyWithPlaceholder() || branch == null
          ? _value.branch
          // ignore: cast_nullable_to_non_nullable
          : branch as String,
    );
  }
}

extension $GitBranchSwitchBodyCopyWith on GitBranchSwitchBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfGitBranchSwitchBody.copyWith(...)` or `instanceOfGitBranchSwitchBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GitBranchSwitchBodyCWProxy get copyWith =>
      _$GitBranchSwitchBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitBranchSwitchBody _$GitBranchSwitchBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GitBranchSwitchBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['path', 'branch']);
      final val = GitBranchSwitchBody(
        path: $checkedConvert('path', (v) => v as String),
        branch: $checkedConvert('branch', (v) => v as String),
      );
      return val;
    });

Map<String, dynamic> _$GitBranchSwitchBodyToJson(
  GitBranchSwitchBody instance,
) => <String, dynamic>{'path': instance.path, 'branch': instance.branch};
