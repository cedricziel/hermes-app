// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'git_pr_list_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$GitPrListBodyCWProxy {
  GitPrListBody path(String path);

  GitPrListBody branches(List<String>? branches);

  GitPrListBody numbers(List<int>? numbers);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitPrListBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitPrListBody(...).copyWith(id: 12, name: "My name")
  /// ```
  GitPrListBody call({String path, List<String>? branches, List<int>? numbers});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfGitPrListBody.copyWith(...)` or call `instanceOfGitPrListBody.copyWith.fieldName(value)` for a single field.
class _$GitPrListBodyCWProxyImpl implements _$GitPrListBodyCWProxy {
  const _$GitPrListBodyCWProxyImpl(this._value);

  final GitPrListBody _value;

  @override
  GitPrListBody path(String path) => call(path: path);

  @override
  GitPrListBody branches(List<String>? branches) => call(branches: branches);

  @override
  GitPrListBody numbers(List<int>? numbers) => call(numbers: numbers);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `GitPrListBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// GitPrListBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  GitPrListBody call({
    Object? path = const $CopyWithPlaceholder(),
    Object? branches = const $CopyWithPlaceholder(),
    Object? numbers = const $CopyWithPlaceholder(),
  }) {
    return GitPrListBody(
      path: path == const $CopyWithPlaceholder() || path == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfGitPrListBody.copyWith(...)` or `instanceOfGitPrListBody.copyWith.fieldName(...)`.
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
