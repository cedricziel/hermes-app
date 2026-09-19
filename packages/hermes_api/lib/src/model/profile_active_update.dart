//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_active_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfileActiveUpdate {
  /// Returns a new [ProfileActiveUpdate] instance.
  ProfileActiveUpdate({required this.name});

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileActiveUpdate && other.name == name;

  @override
  int get hashCode => name.hashCode;

  factory ProfileActiveUpdate.fromJson(Map<String, dynamic> json) =>
      _$ProfileActiveUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileActiveUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
