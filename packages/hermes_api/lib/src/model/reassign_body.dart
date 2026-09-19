//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'reassign_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ReassignBody {
  /// Returns a new [ReassignBody] instance.
  ReassignBody({this.profile, this.reclaimFirst = false, this.reason});

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @JsonKey(
    defaultValue: false,
    name: r'reclaim_first',
    required: false,
    includeIfNull: false,
  )
  final bool? reclaimFirst;

  @JsonKey(name: r'reason', required: false, includeIfNull: false)
  final String? reason;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReassignBody &&
          other.profile == profile &&
          other.reclaimFirst == reclaimFirst &&
          other.reason == reason;

  @override
  int get hashCode =>
      (profile == null ? 0 : profile.hashCode) +
      reclaimFirst.hashCode +
      (reason == null ? 0 : reason.hashCode);

  factory ReassignBody.fromJson(Map<String, dynamic> json) =>
      _$ReassignBodyFromJson(json);

  Map<String, dynamic> toJson() => _$ReassignBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
