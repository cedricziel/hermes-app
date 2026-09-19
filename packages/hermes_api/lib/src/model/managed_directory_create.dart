//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'managed_directory_create.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ManagedDirectoryCreate {
  /// Returns a new [ManagedDirectoryCreate] instance.
  ManagedDirectoryCreate({required this.path});

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManagedDirectoryCreate && other.path == path;

  @override
  int get hashCode => path.hashCode;

  factory ManagedDirectoryCreate.fromJson(Map<String, dynamic> json) =>
      _$ManagedDirectoryCreateFromJson(json);

  Map<String, dynamic> toJson() => _$ManagedDirectoryCreateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
