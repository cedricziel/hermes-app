//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'profile_description_update.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ProfileDescriptionUpdate {
  /// Returns a new [ProfileDescriptionUpdate] instance.
  ProfileDescriptionUpdate({this.description = ''});

  @JsonKey(
    defaultValue: '',
    name: r'description',
    required: false,
    includeIfNull: false,
  )
  final String? description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProfileDescriptionUpdate && other.description == description;

  @override
  int get hashCode => description.hashCode;

  factory ProfileDescriptionUpdate.fromJson(Map<String, dynamic> json) =>
      _$ProfileDescriptionUpdateFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileDescriptionUpdateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
