// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'browsed_download_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrowsedDownloadBodyCWProxy {
  BrowsedDownloadBody repo(String repo);

  BrowsedDownloadBody paths(List<String> paths);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BrowsedDownloadBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BrowsedDownloadBody(...).copyWith(id: 12, name: "My name")
  /// ```
  BrowsedDownloadBody call({String repo, List<String> paths});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfBrowsedDownloadBody.copyWith(...)` or call `instanceOfBrowsedDownloadBody.copyWith.fieldName(value)` for a single field.
class _$BrowsedDownloadBodyCWProxyImpl implements _$BrowsedDownloadBodyCWProxy {
  const _$BrowsedDownloadBodyCWProxyImpl(this._value);

  final BrowsedDownloadBody _value;

  @override
  BrowsedDownloadBody repo(String repo) => call(repo: repo);

  @override
  BrowsedDownloadBody paths(List<String> paths) => call(paths: paths);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BrowsedDownloadBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BrowsedDownloadBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  BrowsedDownloadBody call({
    Object? repo = const $CopyWithPlaceholder(),
    Object? paths = const $CopyWithPlaceholder(),
  }) {
    return BrowsedDownloadBody(
      repo: repo == const $CopyWithPlaceholder() || repo == null
          ? _value.repo
          // ignore: cast_nullable_to_non_nullable
          : repo as String,
      paths: paths == const $CopyWithPlaceholder() || paths == null
          ? _value.paths
          // ignore: cast_nullable_to_non_nullable
          : paths as List<String>,
    );
  }
}

extension $BrowsedDownloadBodyCopyWith on BrowsedDownloadBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfBrowsedDownloadBody.copyWith(...)` or `instanceOfBrowsedDownloadBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BrowsedDownloadBodyCWProxy get copyWith =>
      _$BrowsedDownloadBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BrowsedDownloadBody _$BrowsedDownloadBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BrowsedDownloadBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['repo', 'paths']);
      final val = BrowsedDownloadBody(
        repo: $checkedConvert('repo', (v) => v as String),
        paths: $checkedConvert(
          'paths',
          (v) => (v as List<dynamic>).map((e) => e as String).toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$BrowsedDownloadBodyToJson(
  BrowsedDownloadBody instance,
) => <String, dynamic>{'repo': instance.repo, 'paths': instance.paths};
