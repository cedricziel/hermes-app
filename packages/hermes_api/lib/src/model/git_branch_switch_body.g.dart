// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_branch_switch_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitBranchSwitchBodyCWProxy {
  GitBranchSwitchBody path(String path);

  GitBranchSwitchBody branch(String branch);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitBranchSwitchBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitBranchSwitchBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitBranchSwitchBody call({String path, String branch});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGitBranchSwitchBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGitBranchSwitchBody.copyWith.fieldName(...)`
class _$GitBranchSwitchBodyCWProxyImpl implements _$GitBranchSwitchBodyCWProxy {
  const _$GitBranchSwitchBodyCWProxyImpl(this._value);

  final GitBranchSwitchBody _value;

  @override
  GitBranchSwitchBody path(String path) => this(path: path);

  @override
  GitBranchSwitchBody branch(String branch) => this(branch: branch);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitBranchSwitchBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitBranchSwitchBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitBranchSwitchBody call({
    Object? path = const $CopyWithPlaceholder(),
    Object? branch = const $CopyWithPlaceholder(),
  }) {
    return GitBranchSwitchBody(
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      branch: branch == const $CopyWithPlaceholder()
          ? _value.branch
          // ignore: cast_nullable_to_non_nullable
          : branch as String,
    );
  }
}

extension $GitBranchSwitchBodyCopyWith on GitBranchSwitchBody {
  /// Returns a callable class that can be used as follows: `instanceOfGitBranchSwitchBody.copyWith(...)` or like so:`instanceOfGitBranchSwitchBody.copyWith.fieldName(...)`.
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
