// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_board_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ImportBoardBodyCWProxy {
  ImportBoardBody archive(String archive);

  ImportBoardBody slug(String? slug);

  ImportBoardBody switch_(bool? switch_);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ImportBoardBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ImportBoardBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ImportBoardBody call({String archive, String? slug, bool? switch_});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfImportBoardBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfImportBoardBody.copyWith.fieldName(...)`
class _$ImportBoardBodyCWProxyImpl implements _$ImportBoardBodyCWProxy {
  const _$ImportBoardBodyCWProxyImpl(this._value);

  final ImportBoardBody _value;

  @override
  ImportBoardBody archive(String archive) => this(archive: archive);

  @override
  ImportBoardBody slug(String? slug) => this(slug: slug);

  @override
  ImportBoardBody switch_(bool? switch_) => this(switch_: switch_);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ImportBoardBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ImportBoardBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ImportBoardBody call({
    Object? archive = const $CopyWithPlaceholder(),
    Object? slug = const $CopyWithPlaceholder(),
    Object? switch_ = const $CopyWithPlaceholder(),
  }) {
    return ImportBoardBody(
      archive: archive == const $CopyWithPlaceholder()
          ? _value.archive
          // ignore: cast_nullable_to_non_nullable
          : archive as String,
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String?,
      switch_: switch_ == const $CopyWithPlaceholder()
          ? _value.switch_
          // ignore: cast_nullable_to_non_nullable
          : switch_ as bool?,
    );
  }
}

extension $ImportBoardBodyCopyWith on ImportBoardBody {
  /// Returns a callable class that can be used as follows: `instanceOfImportBoardBody.copyWith(...)` or like so:`instanceOfImportBoardBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ImportBoardBodyCWProxy get copyWith => _$ImportBoardBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImportBoardBody _$ImportBoardBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ImportBoardBody', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['archive']);
      final val = ImportBoardBody(
        archive: $checkedConvert('archive', (v) => v as String),
        slug: $checkedConvert('slug', (v) => v as String?),
        switch_: $checkedConvert('switch', (v) => v as bool? ?? false),
      );
      return val;
    }, fieldKeyMap: const {'switch_': 'switch'});

Map<String, dynamic> _$ImportBoardBodyToJson(ImportBoardBody instance) =>
    <String, dynamic>{
      'archive': instance.archive,
      'slug': ?instance.slug,
      'switch': ?instance.switch_,
    };
