//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'plugin_providers_put_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PluginProvidersPutBody {
  /// Returns a new [PluginProvidersPutBody] instance.
  PluginProvidersPutBody({this.memoryProvider, this.contextEngine});

  @JsonKey(name: r'memory_provider', required: false, includeIfNull: false)
  final String? memoryProvider;

  @JsonKey(name: r'context_engine', required: false, includeIfNull: false)
  final String? contextEngine;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PluginProvidersPutBody &&
          other.memoryProvider == memoryProvider &&
          other.contextEngine == contextEngine;

  @override
  int get hashCode =>
      (memoryProvider == null ? 0 : memoryProvider.hashCode) +
      (contextEngine == null ? 0 : contextEngine.hashCode);

  factory PluginProvidersPutBody.fromJson(Map<String, dynamic> json) =>
      _$PluginProvidersPutBodyFromJson(json);

  Map<String, dynamic> toJson() => _$PluginProvidersPutBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
