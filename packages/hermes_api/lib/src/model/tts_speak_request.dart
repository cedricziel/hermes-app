//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'tts_speak_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TTSSpeakRequest {
  /// Returns a new [TTSSpeakRequest] instance.
  TTSSpeakRequest({required this.text});

  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TTSSpeakRequest && other.text == text;

  @override
  int get hashCode => text.hashCode;

  factory TTSSpeakRequest.fromJson(Map<String, dynamic> json) =>
      _$TTSSpeakRequestFromJson(json);

  Map<String, dynamic> toJson() => _$TTSSpeakRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
