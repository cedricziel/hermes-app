//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'bulk_delete_sessions.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class BulkDeleteSessions {
  /// Returns a new [BulkDeleteSessions] instance.
  BulkDeleteSessions({required this.ids, this.profile});

  @JsonKey(name: r'ids', required: true, includeIfNull: false)
  final List<String> ids;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BulkDeleteSessions &&
          other.ids == ids &&
          other.profile == profile;

  @override
  int get hashCode => ids.hashCode + (profile == null ? 0 : profile.hashCode);

  factory BulkDeleteSessions.fromJson(Map<String, dynamic> json) =>
      _$BulkDeleteSessionsFromJson(json);

  Map<String, dynamic> toJson() => _$BulkDeleteSessionsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
