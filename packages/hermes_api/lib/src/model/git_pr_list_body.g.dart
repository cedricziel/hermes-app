// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_pr_list_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitPrListBodyCWProxy {
  GitPrListBody path(String path);

  GitPrListBody branches(List<String>? branches);

  GitPrListBody numbers(List<int>? numbers);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitPrListBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitPrListBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitPrListBody call({String path, List<String>? branches, List<int>? numbers});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfGitPrListBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfGitPrListBody.copyWith.fieldName(...)`
class _$GitPrListBodyCWProxyImpl implements _$GitPrListBodyCWProxy {
  const _$GitPrListBodyCWProxyImpl(this._value);

  final GitPrListBody _value;

  @override
  GitPrListBody path(String path) => this(path: path);

  @override
  GitPrListBody branches(List<String>? branches) => this(branches: branches);

  @override
  GitPrListBody numbers(List<int>? numbers) => this(numbers: numbers);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `GitPrListBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// GitPrListBody(...).copyWith(id: 12, name: "My name")
  /// ````
  GitPrListBody call({
    Object? path = const $CopyWithPlaceholder(),
    Object? branches = const $CopyWithPlaceholder(),
    Object? numbers = const $CopyWithPlaceholder(),
  }) {
    return GitPrListBody(
      path: path == const $CopyWithPlaceholder()
          ? _value.path
          // ignore: cast_nullable_to_non_nullable
          : path as String,
      branches: branches == const $CopyWithPlaceholder()
          ? _value.branches
          // ignore: cast_nullable_to_non_nullable
          : branches as List<String>?,
      numbers: numbers == const $CopyWithPlaceholder()
          ? _value.numbers
          // ignore: cast_nullable_to_non_nullable
          : numbers as List<int>?,
    );
  }
}

extension $GitPrListBodyCopyWith on GitPrListBody {
  /// Returns a callable class that can be used as follows: `instanceOfGitPrListBody.copyWith(...)` or like so:`instanceOfGitPrListBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$GitPrListBodyCWProxy get copyWith => _$GitPrListBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GitPrListBody _$GitPrListBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('GitPrListBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['path']);
      final val = GitPrListBody(
        path: $checkedConvert('path', (v) => v as String),
        branches: $checkedConvert(
          'branches',
          (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
        ),
        numbers: $checkedConvert(
          'numbers',
          (v) =>
              (v as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ??
              [],
        ),
      );
      return val;
    });

Map<String, dynamic> _$GitPrListBodyToJson(GitPrListBody instance) =>
    <String, dynamic>{
      'path': instance.path,
      'branches': ?instance.branches,
      'numbers': ?instance.numbers,
    };
