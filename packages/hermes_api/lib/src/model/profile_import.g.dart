// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_import.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileImportCWProxy {
  ProfileImport archive(String archive);

  ProfileImport name(String? name);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileImport(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileImport(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileImport call({String archive, String? name});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfProfileImport.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfProfileImport.copyWith.fieldName(...)`
class _$ProfileImportCWProxyImpl implements _$ProfileImportCWProxy {
  const _$ProfileImportCWProxyImpl(this._value);

  final ProfileImport _value;

  @override
  ProfileImport archive(String archive) => this(archive: archive);

  @override
  ProfileImport name(String? name) => this(name: name);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileImport(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileImport(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileImport call({
    Object? archive = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
  }) {
    return ProfileImport(
      archive: archive == const $CopyWithPlaceholder()
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
  /// Returns a callable class that can be used as follows: `instanceOfProfileImport.copyWith(...)` or like so:`instanceOfProfileImport.copyWith.fieldName(...)`.
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
