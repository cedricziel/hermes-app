//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'plugin_visibility_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PluginVisibilityBody {
  /// Returns a new [PluginVisibilityBody] instance.
  PluginVisibilityBody({required this.hidden});

  @JsonKey(name: r'hidden', required: true, includeIfNull: false)
  final bool hidden;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginVisibilityBody && other.hidden == hidden;

  @override
  int get hashCode => hidden.hashCode;

  factory PluginVisibilityBody.fromJson(Map<String, dynamic> json) =>
      _$PluginVisibilityBodyFromJson(json);

  Map<String, dynamic> toJson() => _$PluginVisibilityBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
