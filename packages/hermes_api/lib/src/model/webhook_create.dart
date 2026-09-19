//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'webhook_create.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class WebhookCreate {
  /// Returns a new [WebhookCreate] instance.
  WebhookCreate({
    required this.name,

    this.description,

    this.events = const [],

    this.prompt,

    this.script,

    this.skills = const [],

    this.deliver = 'log',

    this.deliverOnly = false,

    this.deliverChatId,

    this.secret,
  });

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'description', required: false, includeIfNull: false)
  final String? description;

  @JsonKey(
    defaultValue: [],
    name: r'events',
    required: false,
    includeIfNull: false,
  )
  final List<String>? events;

  @JsonKey(name: r'prompt', required: false, includeIfNull: false)
  final String? prompt;

  @JsonKey(name: r'script', required: false, includeIfNull: false)
  final String? script;

  @JsonKey(
    defaultValue: [],
    name: r'skills',
    required: false,
    includeIfNull: false,
  )
  final List<String>? skills;

  @JsonKey(
    defaultValue: 'log',
    name: r'deliver',
    required: false,
    includeIfNull: false,
  )
  final String? deliver;

  @JsonKey(
    defaultValue: false,
    name: r'deliver_only',
    required: false,
    includeIfNull: false,
  )
  final bool? deliverOnly;

  @JsonKey(name: r'deliver_chat_id', required: false, includeIfNull: false)
  final String? deliverChatId;

  @JsonKey(name: r'secret', required: false, includeIfNull: false)
  final String? secret;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebhookCreate &&
          other.name == name &&
          other.description == description &&
          other.events == events &&
          other.prompt == prompt &&
          other.script == script &&
          other.skills == skills &&
          other.deliver == deliver &&
          other.deliverOnly == deliverOnly &&
          other.deliverChatId == deliverChatId &&
          other.secret == secret;

  @override
  int get hashCode =>
      name.hashCode +
      (description == null ? 0 : description.hashCode) +
      events.hashCode +
      (prompt == null ? 0 : prompt.hashCode) +
      (script == null ? 0 : script.hashCode) +
      skills.hashCode +
      deliver.hashCode +
      deliverOnly.hashCode +
      (deliverChatId == null ? 0 : deliverChatId.hashCode) +
      (secret == null ? 0 : secret.hashCode);

  factory WebhookCreate.fromJson(Map<String, dynamic> json) =>
      _$WebhookCreateFromJson(json);

  Map<String, dynamic> toJson() => _$WebhookCreateToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
