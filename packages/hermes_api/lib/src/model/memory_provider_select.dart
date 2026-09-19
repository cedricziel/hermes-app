//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'memory_provider_select.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemoryProviderSelect {
  /// Returns a new [MemoryProviderSelect] instance.
  MemoryProviderSelect({required this.provider});

  @JsonKey(name: r'provider', required: true, includeIfNull: false)
  final String provider;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MemoryProviderSelect && other.provider == provider;

  @override
  int get hashCode => provider.hashCode;

  factory MemoryProviderSelect.fromJson(Map<String, dynamic> json) =>
      _$MemoryProviderSelectFromJson(json);

  Map<String, dynamic> toJson() => _$MemoryProviderSelectToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
