//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_export.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfileExport {
  /// Returns a new [ProfileExport] instance.
  ProfileExport({this.extraFiles = const {}, this.output = ''});

  @JsonKey(
    defaultValue: {},
    name: r'extra_files',
    required: false,
    includeIfNull: false,
  )
  final Map<String, String>? extraFiles;

  @JsonKey(
    defaultValue: '',
    name: r'output',
    required: false,
    includeIfNull: false,
  )
  final String? output;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileExport &&
          other.extraFiles == extraFiles &&
          other.output == output;

  @override
  int get hashCode => extraFiles.hashCode + output.hashCode;

  factory ProfileExport.fromJson(Map<String, dynamic> json) =>
      _$ProfileExportFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileExportToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
