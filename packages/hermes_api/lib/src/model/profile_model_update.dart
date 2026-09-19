//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_model_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfileModelUpdate {
  /// Returns a new [ProfileModelUpdate] instance.
  ProfileModelUpdate({required this.provider, required this.model});

  @JsonKey(name: r'provider', required: true, includeIfNull: false)
  final String provider;

  @JsonKey(name: r'model', required: true, includeIfNull: false)
  final String model;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileModelUpdate &&
          other.provider == provider &&
          other.model == model;

  @override
  int get hashCode => provider.hashCode + model.hashCode;

  factory ProfileModelUpdate.fromJson(Map<String, dynamic> json) =>
      _$ProfileModelUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileModelUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
