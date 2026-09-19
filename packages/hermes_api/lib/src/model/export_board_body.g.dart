// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'export_board_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ExportBoardBodyCWProxy {
  ExportBoardBody output(String? output);

  ExportBoardBody attachments(bool? attachments);

  ExportBoardBody logs(bool? logs);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ExportBoardBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ExportBoardBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ExportBoardBody call({String? output, bool? attachments, bool? logs});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfExportBoardBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfExportBoardBody.copyWith.fieldName(...)`
class _$ExportBoardBodyCWProxyImpl implements _$ExportBoardBodyCWProxy {
  const _$ExportBoardBodyCWProxyImpl(this._value);

  final ExportBoardBody _value;

  @override
  ExportBoardBody output(String? output) => this(output: output);

  @override
  ExportBoardBody attachments(bool? attachments) =>
      this(attachments: attachments);

  @override
  ExportBoardBody logs(bool? logs) => this(logs: logs);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `ExportBoardBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// ExportBoardBody(...).copyWith(id: 12, name: "My name")
  /// ````
  ExportBoardBody call({
    Object? output = const $CopyWithPlaceholder(),
    Object? attachments = const $CopyWithPlaceholder(),
    Object? logs = const $CopyWithPlaceholder(),
  }) {
    return ExportBoardBody(
      output: output == const $CopyWithPlaceholder()
          ? _value.output
          // ignore: cast_nullable_to_non_nullable
          : output as String?,
      attachments: attachments == const $CopyWithPlaceholder()
          ? _value.attachments
          // ignore: cast_nullable_to_non_nullable
          : attachments as bool?,
      logs: logs == const $CopyWithPlaceholder()
          ? _value.logs
          // ignore: cast_nullable_to_non_nullable
          : logs as bool?,
    );
  }
}

extension $ExportBoardBodyCopyWith on ExportBoardBody {
  /// Returns a callable class that can be used as follows: `instanceOfExportBoardBody.copyWith(...)` or like so:`instanceOfExportBoardBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ExportBoardBodyCWProxy get copyWith => _$ExportBoardBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ExportBoardBody _$ExportBoardBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate('ExportBoardBody', json, ($checkedConvert) {
      final val = ExportBoardBody(
        output: $checkedConvert('output', (v) => v as String? ?? ''),
        attachments: $checkedConvert('attachments', (v) => v as bool? ?? true),
        logs: $checkedConvert('logs', (v) => v as bool? ?? false),
      );
      return val;
    });

Map<String, dynamic> _$ExportBoardBodyToJson(ExportBoardBody instance) =>
    <String, dynamic>{
      'output': ?instance.output,
      'attachments': ?instance.attachments,
      'logs': ?instance.logs,
    };
