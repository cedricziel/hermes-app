// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'import_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ImportRequestCWProxy {
  ImportRequest archive(String archive);

  ImportRequest force(bool? force);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ImportRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ImportRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  ImportRequest call({String archive, bool? force});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfImportRequest.copyWith(...)` or call `instanceOfImportRequest.copyWith.fieldName(value)` for a single field.
class _$ImportRequestCWProxyImpl implements _$ImportRequestCWProxy {
  const _$ImportRequestCWProxyImpl(this._value);

  final ImportRequest _value;

  @override
  ImportRequest archive(String archive) => call(archive: archive);

  @override
  ImportRequest force(bool? force) => call(force: force);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ImportRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ImportRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ImportRequest call({
    Object? archive = const $CopyWithPlaceholder(),
    Object? force = const $CopyWithPlaceholder(),
  }) {
    return ImportRequest(
      archive: archive == const $CopyWithPlaceholder() || archive == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfImportRequest.copyWith(...)` or `instanceOfImportRequest.copyWith.fieldName(...)`.
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
