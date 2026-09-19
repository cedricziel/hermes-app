//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'native_refresh_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class NativeRefreshBody {
  /// Returns a new [NativeRefreshBody] instance.
  NativeRefreshBody({required this.refreshToken, this.provider = ''});

  @JsonKey(name: r'refresh_token', required: true, includeIfNull: false)
  final String refreshToken;

  @JsonKey(
    defaultValue: '',
    name: r'provider',
    required: false,
    includeIfNull: false,
  )
  final String? provider;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NativeRefreshBody &&
          other.refreshToken == refreshToken &&
          other.provider == provider;

  @override
  int get hashCode => refreshToken.hashCode + provider.hashCode;

  factory NativeRefreshBody.fromJson(Map<String, dynamic> json) =>
      _$NativeRefreshBodyFromJson(json);

  Map<String, dynamic> toJson() => _$NativeRefreshBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
