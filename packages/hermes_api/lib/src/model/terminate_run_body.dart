//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'terminate_run_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TerminateRunBody {
  /// Returns a new [TerminateRunBody] instance.
  TerminateRunBody({this.reason});

  @JsonKey(name: r'reason', required: false, includeIfNull: false)
  final String? reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminateRunBody && other.reason == reason;

  @override
  int get hashCode => (reason == null ? 0 : reason.hashCode);

  factory TerminateRunBody.fromJson(Map<String, dynamic> json) =>
      _$TerminateRunBodyFromJson(json);

  Map<String, dynamic> toJson() => _$TerminateRunBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
