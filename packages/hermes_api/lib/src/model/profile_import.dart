//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_import.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfileImport {
  /// Returns a new [ProfileImport] instance.
  ProfileImport({required this.archive, this.name});

  @JsonKey(name: r'archive', required: true, includeIfNull: false)
  final String archive;

  @JsonKey(name: r'name', required: false, includeIfNull: false)
  final String? name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileImport && other.archive == archive && other.name == name;

  @override
  int get hashCode => archive.hashCode + (name == null ? 0 : name.hashCode);

  factory ProfileImport.fromJson(Map<String, dynamic> json) =>
      _$ProfileImportFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileImportToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
