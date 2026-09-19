//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'debug_share_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class DebugShareRequest {
  /// Returns a new [DebugShareRequest] instance.
  DebugShareRequest({this.redact = true, this.lines = 200});

  @JsonKey(
    defaultValue: true,
    name: r'redact',
    required: false,
    includeIfNull: false,
  )
  final bool? redact;

  @JsonKey(
    defaultValue: 200,
    name: r'lines',
    required: false,
    includeIfNull: false,
  )
  final int? lines;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DebugShareRequest &&
          other.redact == redact &&
          other.lines == lines;

  @override
  int get hashCode => redact.hashCode + lines.hashCode;

  factory DebugShareRequest.fromJson(Map<String, dynamic> json) =>
      _$DebugShareRequestFromJson(json);

  Map<String, dynamic> toJson() => _$DebugShareRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
