// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'browsed_download_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BrowsedDownloadBodyCWProxy {
  BrowsedDownloadBody repo(String repo);

  BrowsedDownloadBody paths(List<String> paths);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrowsedDownloadBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrowsedDownloadBody(...).copyWith(id: 12, name: "My name")
  /// ````
  BrowsedDownloadBody call({String repo, List<String> paths});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBrowsedDownloadBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBrowsedDownloadBody.copyWith.fieldName(...)`
class _$BrowsedDownloadBodyCWProxyImpl implements _$BrowsedDownloadBodyCWProxy {
  const _$BrowsedDownloadBodyCWProxyImpl(this._value);

  final BrowsedDownloadBody _value;

  @override
  BrowsedDownloadBody repo(String repo) => this(repo: repo);

  @override
  BrowsedDownloadBody paths(List<String> paths) => this(paths: paths);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BrowsedDownloadBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BrowsedDownloadBody(...).copyWith(id: 12, name: "My name")
  /// ````
  BrowsedDownloadBody call({
    Object? repo = const $CopyWithPlaceholder(),
    Object? paths = const $CopyWithPlaceholder(),
  }) {
    return BrowsedDownloadBody(
      repo: repo == const $CopyWithPlaceholder()
          ? _value.repo
          // ignore: cast_nullable_to_non_nullable
          : repo as String,
      paths: paths == const $CopyWithPlaceholder()
          ? _value.paths
          // ignore: cast_nullable_to_non_nullable
          : paths as List<String>,
    );
  }
}

extension $BrowsedDownloadBodyCopyWith on BrowsedDownloadBody {
  /// Returns a callable class that can be used as follows: `instanceOfBrowsedDownloadBody.copyWith(...)` or like so:`instanceOfBrowsedDownloadBody.copyWith.fieldName(...)`.
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
