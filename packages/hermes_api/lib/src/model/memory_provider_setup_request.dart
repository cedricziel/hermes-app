//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'memory_provider_setup_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class MemoryProviderSetupRequest {
  /// Returns a new [MemoryProviderSetupRequest] instance.
  MemoryProviderSetupRequest({this.values = const {}});

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
      other is MemoryProviderSetupRequest && other.values == values;

  @override
  int get hashCode => values.hashCode;

  factory MemoryProviderSetupRequest.fromJson(Map<String, dynamic> json) =>
      _$MemoryProviderSetupRequestFromJson(json);

  Map<String, dynamic> toJson() => _$MemoryProviderSetupRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
