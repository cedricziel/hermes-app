//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'runtime_install_body.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RuntimeInstallBody {
  /// Returns a new [RuntimeInstallBody] instance.
  RuntimeInstallBody({this.backend});

  @JsonKey(name: r'backend', required: false, includeIfNull: false)
  final String? backend;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RuntimeInstallBody && other.backend == backend;

  @override
  int get hashCode => (backend == null ? 0 : backend.hashCode);

  factory RuntimeInstallBody.fromJson(Map<String, dynamic> json) =>
      _$RuntimeInstallBodyFromJson(json);

  Map<String, dynamic> toJson() => _$RuntimeInstallBodyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
