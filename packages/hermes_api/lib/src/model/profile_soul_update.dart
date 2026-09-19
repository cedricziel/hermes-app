//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_soul_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfileSoulUpdate {
  /// Returns a new [ProfileSoulUpdate] instance.
  ProfileSoulUpdate({required this.content});

  @JsonKey(name: r'content', required: true, includeIfNull: false)
  final String content;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileSoulUpdate && other.content == content;

  @override
  int get hashCode => content.hashCode;

  factory ProfileSoulUpdate.fromJson(Map<String, dynamic> json) =>
      _$ProfileSoulUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileSoulUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
