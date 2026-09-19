//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'export_board_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ExportBoardBody {
  /// Returns a new [ExportBoardBody] instance.
  ExportBoardBody({
    this.output = '',

    this.attachments = true,

    this.logs = false,
  });

  @JsonKey(
    defaultValue: '',
    name: r'output',
    required: false,
    includeIfNull: false,
  )
  final String? output;

  @JsonKey(
    defaultValue: true,
    name: r'attachments',
    required: false,
    includeIfNull: false,
  )
  final bool? attachments;

  @JsonKey(
    defaultValue: false,
    name: r'logs',
    required: false,
    includeIfNull: false,
  )
  final bool? logs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExportBoardBody &&
          other.output == output &&
          other.attachments == attachments &&
          other.logs == logs;

  @override
  int get hashCode => output.hashCode + attachments.hashCode + logs.hashCode;

  factory ExportBoardBody.fromJson(Map<String, dynamic> json) =>
      _$ExportBoardBodyFromJson(json);

  Map<String, dynamic> toJson() => _$ExportBoardBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
