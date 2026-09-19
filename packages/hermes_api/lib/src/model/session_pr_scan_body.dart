//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_pr_scan_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionPrScanBody {
  /// Returns a new [SessionPrScanBody] instance.
  SessionPrScanBody({this.ids = const []});

  @JsonKey(
    defaultValue: [],
    name: r'ids',
    required: false,
    includeIfNull: false,
  )
  final List<String>? ids;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SessionPrScanBody && other.ids == ids;

  @override
  int get hashCode => ids.hashCode;

  factory SessionPrScanBody.fromJson(Map<String, dynamic> json) =>
      _$SessionPrScanBodyFromJson(json);

  Map<String, dynamic> toJson() => _$SessionPrScanBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
