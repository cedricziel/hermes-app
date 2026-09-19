//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'password_login_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PasswordLoginBody {
  /// Returns a new [PasswordLoginBody] instance.
  PasswordLoginBody({
    required this.provider,

    required this.username,

    required this.password,

    this.next = '',
  });

  @JsonKey(name: r'provider', required: true, includeIfNull: false)
  final String provider;

  @JsonKey(name: r'username', required: true, includeIfNull: false)
  final String username;

  @JsonKey(name: r'password', required: true, includeIfNull: false)
  final String password;

  @JsonKey(
    defaultValue: '',
    name: r'next',
    required: false,
    includeIfNull: false,
  )
  final String? next;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PasswordLoginBody &&
          other.provider == provider &&
          other.username == username &&
          other.password == password &&
          other.next == next;

  @override
  int get hashCode =>
      provider.hashCode + username.hashCode + password.hashCode + next.hashCode;

  factory PasswordLoginBody.fromJson(Map<String, dynamic> json) =>
      _$PasswordLoginBodyFromJson(json);

  Map<String, dynamic> toJson() => _$PasswordLoginBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
