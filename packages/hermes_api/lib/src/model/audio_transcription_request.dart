//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'audio_transcription_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class AudioTranscriptionRequest {
  /// Returns a new [AudioTranscriptionRequest] instance.
  AudioTranscriptionRequest({required this.dataUrl, this.mimeType});

  @JsonKey(name: r'data_url', required: true, includeIfNull: false)
  final String dataUrl;

  @JsonKey(name: r'mime_type', required: false, includeIfNull: false)
  final String? mimeType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioTranscriptionRequest &&
          other.dataUrl == dataUrl &&
          other.mimeType == mimeType;

  @override
  int get hashCode =>
      dataUrl.hashCode + (mimeType == null ? 0 : mimeType.hashCode);

  factory AudioTranscriptionRequest.fromJson(Map<String, dynamic> json) =>
      _$AudioTranscriptionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$AudioTranscriptionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
