//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'env_var_reveal.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EnvVarReveal {
  /// Returns a new [EnvVarReveal] instance.
  EnvVarReveal({required this.key, this.profile});

  @JsonKey(name: r'key', required: true, includeIfNull: false)
  final String key;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvVarReveal && other.key == key && other.profile == profile;

  @override
  int get hashCode => key.hashCode + (profile == null ? 0 : profile.hashCode);

  factory EnvVarReveal.fromJson(Map<String, dynamic> json) =>
      _$EnvVarRevealFromJson(json);

  Map<String, dynamic> toJson() => _$EnvVarRevealToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
