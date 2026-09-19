//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_rename.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfileRename {
  /// Returns a new [ProfileRename] instance.
  ProfileRename({required this.newName});

  @JsonKey(name: r'new_name', required: true, includeIfNull: false)
  final String newName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileRename && other.newName == newName;

  @override
  int get hashCode => newName.hashCode;

  factory ProfileRename.fromJson(Map<String, dynamic> json) =>
      _$ProfileRenameFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileRenameToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
