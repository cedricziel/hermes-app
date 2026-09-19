// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_path_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitPathBodyCWProxy {
  GitPathBody path(String path);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitPathBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitPathBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitPathBody call({String path});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGitPathBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGitPathBody.copyWith.fieldName(...)`
class _$GitPathBodyCWProxyImpl implements _$GitPathBodyCWProxy {
  const _$GitPathBodyCWProxyImpl(this._value);

  final GitPathBody _value;

  @override
  GitPathBody path(String path) => this(path: path);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitPathBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitPathBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitPathBody call({Object? path = const $CopyWithPlaceholder()}) {
    return GitPathBody(
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
    );
  }
}

extension $GitPathBodyCopyWith on GitPathBody {
  /// Returns a callable class that can be used as follows: `instanceOfGitPathBody.copyWith(...)` or like so:`instanceOfGitPathBody.copyWith.fieldName(...)`.
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
