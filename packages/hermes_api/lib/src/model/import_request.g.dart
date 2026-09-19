// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ImportRequestCWProxy {
  ImportRequest archive(String archive);

  ImportRequest force(bool? force);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ImportRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ImportRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ImportRequest call({String archive, bool? force});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfImportRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfImportRequest.copyWith.fieldName(...)`
class _$ImportRequestCWProxyImpl implements _$ImportRequestCWProxy {
  const _$ImportRequestCWProxyImpl(this._value);

  final ImportRequest _value;

  @override
  ImportRequest archive(String archive) => this(archive: archive);

  @override
  ImportRequest force(bool? force) => this(force: force);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ImportRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ImportRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  ImportRequest call({
    Object? archive = const $CopyWithPlaceholder(),
    Object? force = const $CopyWithPlaceholder(),
  }) {
    return ImportRequest(
      archive: archive == const $CopyWithPlaceholder()
          ? _value.archive
          // ignore: cast_nullable_to_non_nullable
          : archive as String,
      force: force == const $CopyWithPlaceholder()
          ? _value.force
          // ignore: cast_nullable_to_non_nullable
          : force as bool?,
    );
  }
}

extension $ImportRequestCopyWith on ImportRequest {
  /// Returns a callable class that can be used as follows: `instanceOfImportRequest.copyWith(...)` or like so:`instanceOfImportRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ImportRequestCWProxy get copyWith => _$ImportRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ImportRequest _$ImportRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ImportRequest', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['archive']);
      final val = ImportRequest(
        archive: $checkedConvert('archive', (v) => v as String),
        force: $checkedConvert('force', (v) => v as bool? ?? false),
      );
      return val;
    });

Map<String, dynamic> _$ImportRequestToJson(ImportRequest instance) =>
    <String, dynamic>{'archive': instance.archive, 'force': ?instance.force};
