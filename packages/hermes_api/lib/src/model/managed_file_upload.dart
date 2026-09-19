//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'managed_file_upload.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ManagedFileUpload {
  /// Returns a new [ManagedFileUpload] instance.
  ManagedFileUpload({
    required this.path,

    required this.dataUrl,

    this.overwrite = true,
  });

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @JsonKey(name: r'data_url', required: true, includeIfNull: false)
  final String dataUrl;

  @JsonKey(
    defaultValue: true,
    name: r'overwrite',
    required: false,
    includeIfNull: false,
  )
  final bool? overwrite;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ManagedFileUpload &&
          other.path == path &&
          other.dataUrl == dataUrl &&
          other.overwrite == overwrite;

  @override
  int get hashCode => path.hashCode + dataUrl.hashCode + overwrite.hashCode;

  factory ManagedFileUpload.fromJson(Map<String, dynamic> json) =>
      _$ManagedFileUploadFromJson(json);

  Map<String, dynamic> toJson() => _$ManagedFileUploadToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
