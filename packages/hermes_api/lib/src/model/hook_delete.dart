//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'hook_delete.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HookDelete {
  /// Returns a new [HookDelete] instance.
  HookDelete({required this.event, required this.command});

  @JsonKey(name: r'event', required: true, includeIfNull: false)
  final String event;

  @JsonKey(name: r'command', required: true, includeIfNull: false)
  final String command;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HookDelete && other.event == event && other.command == command;

  @override
  int get hashCode => event.hashCode + command.hashCode;

  factory HookDelete.fromJson(Map<String, dynamic> json) =>
      _$HookDeleteFromJson(json);

  Map<String, dynamic> toJson() => _$HookDeleteToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
