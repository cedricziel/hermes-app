// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_commit_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitCommitBodyCWProxy {
  GitCommitBody path(String path);

  GitCommitBody message(String message);

  GitCommitBody push(bool? push);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitCommitBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitCommitBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitCommitBody call({String path, String message, bool? push});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGitCommitBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGitCommitBody.copyWith.fieldName(...)`
class _$GitCommitBodyCWProxyImpl implements _$GitCommitBodyCWProxy {
  const _$GitCommitBodyCWProxyImpl(this._value);

  final GitCommitBody _value;

  @override
  GitCommitBody path(String path) => this(path: path);

  @override
  GitCommitBody message(String message) => this(message: message);

  @override
  GitCommitBody push(bool? push) => this(push: push);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitCommitBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitCommitBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitCommitBody call({
    Object? path = const $CopyWithPlaceholder(),
    Object? message = const $CopyWithPlaceholder(),
    Object? push = const $CopyWithPlaceholder(),
  }) {
    return GitCommitBody(
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      message: message == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfGitCommitBody.copyWith(...)` or like so:`instanceOfGitCommitBody.copyWith.fieldName(...)`.
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
