//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'sideload_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SideloadBody {
  /// Returns a new [SideloadBody] instance.
  SideloadBody({required this.path});

  @JsonKey(name: r'path', required: true, includeIfNull: false)
  final String path;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SideloadBody && other.path == path;

  @override
  int get hashCode => path.hashCode;

  factory SideloadBody.fromJson(Map<String, dynamic> json) =>
      _$SideloadBodyFromJson(json);

  Map<String, dynamic> toJson() => _$SideloadBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
