//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'webhook_enabled_toggle.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WebhookEnabledToggle {
  /// Returns a new [WebhookEnabledToggle] instance.
  WebhookEnabledToggle({required this.enabled});

  @JsonKey(name: r'enabled', required: true, includeIfNull: false)
  final bool enabled;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebhookEnabledToggle && other.enabled == enabled;

  @override
  int get hashCode => enabled.hashCode;

  factory WebhookEnabledToggle.fromJson(Map<String, dynamic> json) =>
      _$WebhookEnabledToggleFromJson(json);

  Map<String, dynamic> toJson() => _$WebhookEnabledToggleToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
