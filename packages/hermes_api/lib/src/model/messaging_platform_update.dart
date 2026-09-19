//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'messaging_platform_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MessagingPlatformUpdate {
  /// Returns a new [MessagingPlatformUpdate] instance.
  MessagingPlatformUpdate({
    this.enabled,

    this.env = const {},

    this.clearEnv = const [],

    this.profile,
  });

  @JsonKey(name: r'enabled', required: false, includeIfNull: false)
  final bool? enabled;

  @JsonKey(
    defaultValue: {},
    name: r'env',
    required: false,
    includeIfNull: false,
  )
  final Map<String, String>? env;

  @JsonKey(
    defaultValue: [],
    name: r'clear_env',
    required: false,
    includeIfNull: false,
  )
  final List<String>? clearEnv;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessagingPlatformUpdate &&
          other.enabled == enabled &&
          other.env == env &&
          other.clearEnv == clearEnv &&
          other.profile == profile;

  @override
  int get hashCode =>
      (enabled == null ? 0 : enabled.hashCode) +
      env.hashCode +
      clearEnv.hashCode +
      (profile == null ? 0 : profile.hashCode);

  factory MessagingPlatformUpdate.fromJson(Map<String, dynamic> json) =>
      _$MessagingPlatformUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$MessagingPlatformUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
