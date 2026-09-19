//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'o_auth_submit_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OAuthSubmitBody {
  /// Returns a new [OAuthSubmitBody] instance.
  OAuthSubmitBody({required this.sessionId, required this.code});

  @JsonKey(name: r'session_id', required: true, includeIfNull: false)
  final String sessionId;

  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OAuthSubmitBody &&
          other.sessionId == sessionId &&
          other.code == code;

  @override
  int get hashCode => sessionId.hashCode + code.hashCode;

  factory OAuthSubmitBody.fromJson(Map<String, dynamic> json) =>
      _$OAuthSubmitBodyFromJson(json);

  Map<String, dynamic> toJson() => _$OAuthSubmitBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
