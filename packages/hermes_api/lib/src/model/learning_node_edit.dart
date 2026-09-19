//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'learning_node_edit.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LearningNodeEdit {
  /// Returns a new [LearningNodeEdit] instance.
  LearningNodeEdit({required this.id, required this.content, this.profile});

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final String id;

  @JsonKey(name: r'content', required: true, includeIfNull: false)
  final String content;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LearningNodeEdit &&
          other.id == id &&
          other.content == content &&
          other.profile == profile;

  @override
  int get hashCode =>
      id.hashCode + content.hashCode + (profile == null ? 0 : profile.hashCode);

  factory LearningNodeEdit.fromJson(Map<String, dynamic> json) =>
      _$LearningNodeEditFromJson(json);

  Map<String, dynamic> toJson() => _$LearningNodeEditToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
