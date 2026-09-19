//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'link_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LinkBody {
  /// Returns a new [LinkBody] instance.
  LinkBody({required this.parentId, required this.childId});

  @JsonKey(name: r'parent_id', required: true, includeIfNull: false)
  final String parentId;

  @JsonKey(name: r'child_id', required: true, includeIfNull: false)
  final String childId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LinkBody &&
          other.parentId == parentId &&
          other.childId == childId;

  @override
  int get hashCode => parentId.hashCode + childId.hashCode;

  factory LinkBody.fromJson(Map<String, dynamic> json) =>
      _$LinkBodyFromJson(json);

  Map<String, dynamic> toJson() => _$LinkBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
