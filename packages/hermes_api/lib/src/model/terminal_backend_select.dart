//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'terminal_backend_select.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TerminalBackendSelect {
  /// Returns a new [TerminalBackendSelect] instance.
  TerminalBackendSelect({required this.backend, this.profile});

  @JsonKey(name: r'backend', required: true, includeIfNull: false)
  final String backend;

  @JsonKey(name: r'profile', required: false, includeIfNull: false)
  final String? profile;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TerminalBackendSelect &&
          other.backend == backend &&
          other.profile == profile;

  @override
  int get hashCode =>
      backend.hashCode + (profile == null ? 0 : profile.hashCode);

  factory TerminalBackendSelect.fromJson(Map<String, dynamic> json) =>
      _$TerminalBackendSelectFromJson(json);

  Map<String, dynamic> toJson() => _$TerminalBackendSelectToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
