//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'env_var_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EnvVarUpdate {
  /// Returns a new [EnvVarUpdate] instance.
  EnvVarUpdate({
    required this.key,

    required this.value,

    this.profile,

    this.apiKey = '',
  });

  @JsonKey(name: r'key', required: true, includeIfNull: false)
  final String key;

  @JsonKey(name: r'value', required: true, includeIfNull: false)
  final String value;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @JsonKey(
    defaultValue: '',
    name: r'api_key',
    required: false,
    includeIfNull: false,
  )
  final String? apiKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EnvVarUpdate &&
          other.key == key &&
          other.value == value &&
          other.profile == profile &&
          other.apiKey == apiKey;

  @override
  int get hashCode =>
      key.hashCode +
      value.hashCode +
      (profile == null ? 0 : profile.hashCode) +
      apiKey.hashCode;

  factory EnvVarUpdate.fromJson(Map<String, dynamic> json) =>
      _$EnvVarUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$EnvVarUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
