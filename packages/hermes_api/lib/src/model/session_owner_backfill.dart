//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'session_owner_backfill.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SessionOwnerBackfill {
  /// Returns a new [SessionOwnerBackfill] instance.
  SessionOwnerBackfill({this.profile});

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionOwnerBackfill && other.profile == profile;

  @override
  int get hashCode => (profile == null ? 0 : profile.hashCode);

  factory SessionOwnerBackfill.fromJson(Map<String, dynamic> json) =>
      _$SessionOwnerBackfillFromJson(json);

  Map<String, dynamic> toJson() => _$SessionOwnerBackfillToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
