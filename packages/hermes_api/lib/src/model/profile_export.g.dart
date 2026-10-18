// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_export.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileExportCWProxy {
  ProfileExport extraFiles(Map<String, String>? extraFiles);

  ProfileExport output(String? output);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileExport(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileExport(...).copyWith(id: 12, name: "My name")
  /// ```
  ProfileExport call({Map<String, String>? extraFiles, String? output});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfileExport.copyWith(...)` or call `instanceOfProfileExport.copyWith.fieldName(value)` for a single field.
class _$ProfileExportCWProxyImpl implements _$ProfileExportCWProxy {
  const _$ProfileExportCWProxyImpl(this._value);

  final ProfileExport _value;

  @override
  ProfileExport extraFiles(Map<String, String>? extraFiles) =>
      call(extraFiles: extraFiles);

  @override
  ProfileExport output(String? output) => call(output: output);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileExport(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileExport(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfileExport.copyWith(...)` or `instanceOfProfileExport.copyWith.fieldName(...)`.
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
