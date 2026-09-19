//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'native_token_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NativeTokenBody {
  /// Returns a new [NativeTokenBody] instance.
  NativeTokenBody({required this.code, required this.codeVerifier});

  @JsonKey(name: r'code', required: true, includeIfNull: false)
  final String code;

  @JsonKey(name: r'code_verifier', required: true, includeIfNull: false)
  final String codeVerifier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeTokenBody &&
          other.code == code &&
          other.codeVerifier == codeVerifier;

  @override
  int get hashCode => code.hashCode + codeVerifier.hashCode;

  factory NativeTokenBody.fromJson(Map<String, dynamic> json) =>
      _$NativeTokenBodyFromJson(json);

  Map<String, dynamic> toJson() => _$NativeTokenBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
