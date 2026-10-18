// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BackupRequestCWProxy {
  BackupRequest output(String? output);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BackupRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BackupRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  BackupRequest call({String? output});
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfBackupRequest.copyWith(...)` or call `instanceOfBackupRequest.copyWith.fieldName(value)` for a single field.
class _$BackupRequestCWProxyImpl implements _$BackupRequestCWProxy {
  const _$BackupRequestCWProxyImpl(this._value);

  final BackupRequest _value;

  @override
  BackupRequest output(String? output) => call(output: output);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `BackupRequest(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// BackupRequest(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  BackupRequest call({Object? output = const $CopyWithPlaceholder()}) {
    return BackupRequest(
      output: output == const $CopyWithPlaceholder()
          ? _value.output
          // ignore: cast_nullable_to_non_nullable
          : output as String?,
    );
  }
}

extension $BackupRequestCopyWith on BackupRequest {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfBackupRequest.copyWith(...)` or `instanceOfBackupRequest.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$BackupRequestCWProxy get copyWith => _$BackupRequestCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

BackupRequest _$BackupRequestFromJson(Map<String, dynamic> json) =>
    $checkedCreate('BackupRequest', json, ($checkedConvert) {
      final val = BackupRequest(
        output: $checkedConvert('output', (v) => v as String?),
      );
      return val;
    });

Map<String, dynamic> _$BackupRequestToJson(BackupRequest instance) =>
    <String, dynamic>{'output': ?instance.output};
