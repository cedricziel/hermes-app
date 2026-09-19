//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'managed_file_delete.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ManagedFileDelete {
  /// Returns a new [ManagedFileDelete] instance.
  ManagedFileDelete({required this.path, this.recursive = false});

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @JsonKey(
    defaultValue: false,
    name: r'recursive',
    required: false,
    includeIfNull: false,
  )
  final bool? recursive;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManagedFileDelete &&
          other.path == path &&
          other.recursive == recursive;

  @override
  int get hashCode => path.hashCode + recursive.hashCode;

  factory ManagedFileDelete.fromJson(Map<String, dynamic> json) =>
      _$ManagedFileDeleteFromJson(json);

  Map<String, dynamic> toJson() => _$ManagedFileDeleteToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
