//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'credential_pool_add.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class CredentialPoolAdd {
  /// Returns a new [CredentialPoolAdd] instance.
  CredentialPoolAdd({required this.provider, required this.apiKey, this.label});

  @JsonKey(name: r'provider', required: true, includeIfNull: false)
  final String provider;

  @JsonKey(name: r'api_key', required: true, includeIfNull: false)
  final String apiKey;

  @JsonKey(name: r'label', required: false, includeIfNull: false)
  final String? label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CredentialPoolAdd &&
          other.provider == provider &&
          other.apiKey == apiKey &&
          other.label == label;

  @override
  int get hashCode =>
      provider.hashCode +
      apiKey.hashCode +
      (label == null ? 0 : label.hashCode);

  factory CredentialPoolAdd.fromJson(Map<String, dynamic> json) =>
      _$CredentialPoolAddFromJson(json);

  Map<String, dynamic> toJson() => _$CredentialPoolAddToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
