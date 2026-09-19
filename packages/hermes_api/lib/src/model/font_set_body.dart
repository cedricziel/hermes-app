//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'font_set_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class FontSetBody {
  /// Returns a new [FontSetBody] instance.
  FontSetBody({required this.font});

  @JsonKey(name: r'font', required: true, includeIfNull: false)
  final String font;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is FontSetBody && other.font == font;

  @override
  int get hashCode => font.hashCode;

  factory FontSetBody.fromJson(Map<String, dynamic> json) =>
      _$FontSetBodyFromJson(json);

  Map<String, dynamic> toJson() => _$FontSetBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
