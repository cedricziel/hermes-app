//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'hook_create.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HookCreate {
  /// Returns a new [HookCreate] instance.
  HookCreate({
    required this.event,

    required this.command,

    this.matcher,

    this.timeout,

    this.approve = true,
  });

  @JsonKey(name: r'event', required: true, includeIfNull: false)
  final String event;

  @JsonKey(name: r'command', required: true, includeIfNull: false)
  final String command;

  @JsonKey(name: r'matcher', required: false, includeIfNull: false)
  final String? matcher;

  @JsonKey(name: r'timeout', required: false, includeIfNull: false)
  final int? timeout;

  @JsonKey(
    defaultValue: true,
    name: r'approve',
    required: false,
    includeIfNull: false,
  )
  final bool? approve;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HookCreate &&
          other.event == event &&
          other.command == command &&
          other.matcher == matcher &&
          other.timeout == timeout &&
          other.approve == approve;

  @override
  int get hashCode =>
      event.hashCode +
      command.hashCode +
      (matcher == null ? 0 : matcher.hashCode) +
      (timeout == null ? 0 : timeout.hashCode) +
      approve.hashCode;

  factory HookCreate.fromJson(Map<String, dynamic> json) =>
      _$HookCreateFromJson(json);

  Map<String, dynamic> toJson() => _$HookCreateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
