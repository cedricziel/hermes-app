//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'estimate_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class EstimateBody {
  /// Returns a new [EstimateBody] instance.
  EstimateBody({this.title = '', this.body});

  @JsonKey(
    defaultValue: '',
    name: r'title',
    required: false,
    includeIfNull: false,
  )
  final String? title;

  @JsonKey(name: r'body', required: false, includeIfNull: false)
  final String? body;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EstimateBody && other.title == title && other.body == body;

  @override
  int get hashCode => title.hashCode + (body == null ? 0 : body.hashCode);

  factory EstimateBody.fromJson(Map<String, dynamic> json) =>
      _$EstimateBodyFromJson(json);

  Map<String, dynamic> toJson() => _$EstimateBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
