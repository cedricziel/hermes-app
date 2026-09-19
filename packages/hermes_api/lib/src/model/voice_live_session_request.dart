//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'voice_live_session_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class VoiceLiveSessionRequest {
  /// Returns a new [VoiceLiveSessionRequest] instance.
  VoiceLiveSessionRequest({required this.sdp, this.history});

  @JsonKey(name: r'sdp', required: true, includeIfNull: false)
  final String sdp;

  @JsonKey(name: r'history', required: false, includeIfNull: false)
  final List<Map<String, Object>>? history;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceLiveSessionRequest &&
          other.sdp == sdp &&
          other.history == history;

  @override
  int get hashCode => sdp.hashCode + (history == null ? 0 : history.hashCode);

  factory VoiceLiveSessionRequest.fromJson(Map<String, dynamic> json) =>
      _$VoiceLiveSessionRequestFromJson(json);

  Map<String, dynamic> toJson() => _$VoiceLiveSessionRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
