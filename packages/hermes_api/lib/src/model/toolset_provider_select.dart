//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'toolset_provider_select.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ToolsetProviderSelect {
  /// Returns a new [ToolsetProviderSelect] instance.
  ToolsetProviderSelect({
    required this.provider,

    this.capability,

    this.profile,
  });

  @JsonKey(name: r'provider', required: true, includeIfNull: false)
  final String provider;

  @JsonKey(name: r'capability', required: false, includeIfNull: false)
  final String? capability;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ToolsetProviderSelect &&
          other.provider == provider &&
          other.capability == capability &&
          other.profile == profile;

  @override
  int get hashCode =>
      provider.hashCode +
      (capability == null ? 0 : capability.hashCode) +
      (profile == null ? 0 : profile.hashCode);

  factory ToolsetProviderSelect.fromJson(Map<String, dynamic> json) =>
      _$ToolsetProviderSelectFromJson(json);

  Map<String, dynamic> toJson() => _$ToolsetProviderSelectToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
