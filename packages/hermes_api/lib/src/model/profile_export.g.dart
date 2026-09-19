// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_export.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileExportCWProxy {
  ProfileExport extraFiles(Map<String, String>? extraFiles);

  ProfileExport output(String? output);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileExport(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileExport(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileExport call({Map<String, String>? extraFiles, String? output});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfProfileExport.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfProfileExport.copyWith.fieldName(...)`
class _$ProfileExportCWProxyImpl implements _$ProfileExportCWProxy {
  const _$ProfileExportCWProxyImpl(this._value);

  final ProfileExport _value;

  @override
  ProfileExport extraFiles(Map<String, String>? extraFiles) =>
      this(extraFiles: extraFiles);

  @override
  ProfileExport output(String? output) => this(output: output);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ProfileExport(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ProfileExport(...).copyWith(id: 12, name: "My name")
  /// ````
  ProfileExport call({
    Object? extraFiles = const $CopyWithPlaceholder(),
    Object? output = const $CopyWithPlaceholder(),
  }) {
    return ProfileExport(
      extraFiles: extraFiles == const $CopyWithPlaceholder()
          ? _value.extraFiles
          // ignore: cast_nullable_to_non_nullable
          : extraFiles as Map<String, String>?,
      output: output == const $CopyWithPlaceholder()
          ? _value.output
          // ignore: cast_nullable_to_non_nullable
          : output as String?,
    );
  }
}

extension $ProfileExportCopyWith on ProfileExport {
  /// Returns a callable class that can be used as follows: `instanceOfProfileExport.copyWith(...)` or like so:`instanceOfProfileExport.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileExportCWProxy get copyWith => _$ProfileExportCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileExport _$ProfileExportFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ProfileExport', json, ($checkedConvert) {
      final val = ProfileExport(
        extraFiles: $checkedConvert(
          'extra_files',
          (v) =>
              (v as Map<String, dynamic>?)?.map(
                (k, e) => MapEntry(k, e as String),
              ) ??
              {},
        ),
        output: $checkedConvert('output', (v) => v as String? ?? ''),
      );
      return val;
    }, fieldKeyMap: const {'extraFiles': 'extra_files'});

Map<String, dynamic> _$ProfileExportToJson(ProfileExport instance) =>
    <String, dynamic>{
      'extra_files': ?instance.extraFiles,
      'output': ?instance.output,
    };
