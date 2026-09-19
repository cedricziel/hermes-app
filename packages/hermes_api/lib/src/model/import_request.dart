//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'import_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class ImportRequest {
  /// Returns a new [ImportRequest] instance.
  ImportRequest({required this.archive, this.force = false});

  @JsonKey(name: r'archive', required: true, includeIfNull: false)
  final String archive;

  @JsonKey(
    defaultValue: false,
    name: r'force',
    required: false,
    includeIfNull: false,
  )
  final bool? force;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ImportRequest &&
          other.archive == archive &&
          other.force == force;

  @override
  int get hashCode => archive.hashCode + force.hashCode;

  factory ImportRequest.fromJson(Map<String, dynamic> json) =>
      _$ImportRequestFromJson(json);

  Map<String, dynamic> toJson() => _$ImportRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
