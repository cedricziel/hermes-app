//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'theme_set_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ThemeSetBody {
  /// Returns a new [ThemeSetBody] instance.
  ThemeSetBody({required this.name});

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ThemeSetBody && other.name == name;

  @override
  int get hashCode => name.hashCode;

  factory ThemeSetBody.fromJson(Map<String, dynamic> json) =>
      _$ThemeSetBodyFromJson(json);

  Map<String, dynamic> toJson() => _$ThemeSetBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
