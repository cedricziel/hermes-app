//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'learning_node_ref.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LearningNodeRef {
  /// Returns a new [LearningNodeRef] instance.
  LearningNodeRef({required this.id, this.profile});

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningNodeRef && other.id == id && other.profile == profile;

  @override
  int get hashCode => id.hashCode + (profile == null ? 0 : profile.hashCode);

  factory LearningNodeRef.fromJson(Map<String, dynamic> json) =>
      _$LearningNodeRefFromJson(json);

  Map<String, dynamic> toJson() => _$LearningNodeRefToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
