// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_import.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileImportCWProxy {
  ProfileImport archive(String archive);

  ProfileImport name(String? name);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileImport(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileImport(...).copyWith(id: 12, name: "My name")
  /// ```
  ProfileImport call({String archive, String? name});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfileImport.copyWith(...)` or call `instanceOfProfileImport.copyWith.fieldName(value)` for a single field.
class _$ProfileImportCWProxyImpl implements _$ProfileImportCWProxy {
  const _$ProfileImportCWProxyImpl(this._value);

  final ProfileImport _value;

  @override
  ProfileImport archive(String archive) => call(archive: archive);

  @override
  ProfileImport name(String? name) => call(name: name);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileImport(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileImport(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ProfileImport call({
    Object? archive = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
  }) {
    return ProfileImport(
      archive: archive == const $CopyWithPlaceholder() || archive == null
          ? _value.archive
          // ignore: cast_nullable_to_non_nullable
          : archive as String,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String?,
    );
  }
}

extension $ProfileImportCopyWith on ProfileImport {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfileImport.copyWith(...)` or `instanceOfProfileImport.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileImportCWProxy get copyWith => _$ProfileImportCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileImport _$ProfileImportFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProfileImport', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['archive']);
      final val = ProfileImport(
        archive: $checkedConvert('archive', (v) => v as String),
        name: $checkedConvert('name', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$ProfileImportToJson(ProfileImport instance) =>
    <String, dynamic>{'archive': instance.archive, 'name': ?instance.name};
