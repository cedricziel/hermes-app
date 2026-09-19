//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'chat_image_upload.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ChatImageUpload {
  /// Returns a new [ChatImageUpload] instance.
  ChatImageUpload({required this.dataUrl, this.filename});

  @JsonKey(name: r'data_url', required: true, includeIfNull: false)
  final String dataUrl;

  @JsonKey(name: r'filename', required: false, includeIfNull: false)
  final String? filename;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatImageUpload &&
          other.dataUrl == dataUrl &&
          other.filename == filename;

  @override
  int get hashCode =>
      dataUrl.hashCode + (filename == null ? 0 : filename.hashCode);

  factory ChatImageUpload.fromJson(Map<String, dynamic> json) =>
      _$ChatImageUploadFromJson(json);

  Map<String, dynamic> toJson() => _$ChatImageUploadToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
