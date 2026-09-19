//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'memory_provider_config_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemoryProviderConfigUpdate {
  /// Returns a new [MemoryProviderConfigUpdate] instance.
  MemoryProviderConfigUpdate({this.values = const {}});

  @JsonKey(
    defaultValue: {},
    name: r'values',
    required: false,
    includeIfNull: false,
  )
  final Map<String, Object>? values;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryProviderConfigUpdate && other.values == values;

  @override
  int get hashCode => values.hashCode;

  factory MemoryProviderConfigUpdate.fromJson(Map<String, dynamic> json) =>
      _$MemoryProviderConfigUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$MemoryProviderConfigUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
