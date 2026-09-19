//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'import_board_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ImportBoardBody {
  /// Returns a new [ImportBoardBody] instance.
  ImportBoardBody({required this.archive, this.slug, this.switch_ = false});

  @JsonKey(name: r'archive', required: true, includeIfNull: false)
  final String archive;

  @JsonKey(name: r'slug', required: false, includeIfNull: false)
  final String? slug;

  @JsonKey(
    defaultValue: false,
    name: r'switch',
    required: false,
    includeIfNull: false,
  )
  final bool? switch_;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportBoardBody &&
          other.archive == archive &&
          other.slug == slug &&
          other.switch_ == switch_;

  @override
  int get hashCode =>
      archive.hashCode + (slug == null ? 0 : slug.hashCode) + switch_.hashCode;

  factory ImportBoardBody.fromJson(Map<String, dynamic> json) =>
      _$ImportBoardBodyFromJson(json);

  Map<String, dynamic> toJson() => _$ImportBoardBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
