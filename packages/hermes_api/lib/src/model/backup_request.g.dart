// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup_request.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$BackupRequestCWProxy {
  BackupRequest output(String? output);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BackupRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BackupRequest(...).copyWith(id: 12, name: "My name")
  /// ````
  BackupRequest call({String? output});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfBackupRequest.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfBackupRequest.copyWith.fieldName(...)`
class _$BackupRequestCWProxyImpl implements _$BackupRequestCWProxy {
  const _$BackupRequestCWProxyImpl(this._value);

  final BackupRequest _value;

  @override
  BackupRequest output(String? output) => this(output: output);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `BackupRequest(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// BackupRequest(...).copyWith(id: 12, name: "My name")
  /// ````
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
  /// Returns a callable class that can be used as follows: `instanceOfBackupRequest.copyWith(...)` or like so:`instanceOfBackupRequest.copyWith.fieldName(...)`.
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
