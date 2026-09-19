// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webhook_create.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$WebhookCreateCWProxy {
  WebhookCreate name(String name);

  WebhookCreate description(String? description);

  WebhookCreate events(List<String>? events);

  WebhookCreate prompt(String? prompt);

  WebhookCreate script(String? script);

  WebhookCreate skills(List<String>? skills);

  WebhookCreate deliver(String? deliver);

  WebhookCreate deliverOnly(bool? deliverOnly);

  WebhookCreate deliverChatId(String? deliverChatId);

  WebhookCreate secret(String? secret);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebhookCreate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebhookCreate(...).copyWith(id: 12, name: "My name")
  /// ````
  WebhookCreate call({
    String name,
    String? description,
    List<String>? events,
    String? prompt,
    String? script,
    List<String>? skills,
    String? deliver,
    bool? deliverOnly,
    String? deliverChatId,
    String? secret,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfWebhookCreate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfWebhookCreate.copyWith.fieldName(...)`
class _$WebhookCreateCWProxyImpl implements _$WebhookCreateCWProxy {
  const _$WebhookCreateCWProxyImpl(this._value);

  final WebhookCreate _value;

  @override
  WebhookCreate name(String name) => this(name: name);

  @override
  WebhookCreate description(String? description) =>
      this(description: description);

  @override
  WebhookCreate events(List<String>? events) => this(events: events);

  @override
  WebhookCreate prompt(String? prompt) => this(prompt: prompt);

  @override
  WebhookCreate script(String? script) => this(script: script);

  @override
  WebhookCreate skills(List<String>? skills) => this(skills: skills);

  @override
  WebhookCreate deliver(String? deliver) => this(deliver: deliver);

  @override
  WebhookCreate deliverOnly(bool? deliverOnly) =>
      this(deliverOnly: deliverOnly);

  @override
  WebhookCreate deliverChatId(String? deliverChatId) =>
      this(deliverChatId: deliverChatId);

  @override
  WebhookCreate secret(String? secret) => this(secret: secret);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `WebhookCreate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// WebhookCreate(...).copyWith(id: 12, name: "My name")
  /// ````
  WebhookCreate call({
    Object? name = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? events = const $CopyWithPlaceholder(),
    Object? prompt = const $CopyWithPlaceholder(),
    Object? script = const $CopyWithPlaceholder(),
    Object? skills = const $CopyWithPlaceholder(),
    Object? deliver = const $CopyWithPlaceholder(),
    Object? deliverOnly = const $CopyWithPlaceholder(),
    Object? deliverChatId = const $CopyWithPlaceholder(),
    Object? secret = const $CopyWithPlaceholder(),
  }) {
    return WebhookCreate(
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String?,
      events: events == const $CopyWithPlaceholder()
          ? _value.events
          // ignore: cast_nullable_to_non_nullable
          : events as List<String>?,
      prompt: prompt == const $CopyWithPlaceholder()
          ? _value.prompt
          // ignore: cast_nullable_to_non_nullable
          : prompt as String?,
      script: script == const $CopyWithPlaceholder()
          ? _value.script
          // ignore: cast_nullable_to_non_nullable
          : script as String?,
      skills: skills == const $CopyWithPlaceholder()
          ? _value.skills
          // ignore: cast_nullable_to_non_nullable
          : skills as List<String>?,
      deliver: deliver == const $CopyWithPlaceholder()
          ? _value.deliver
          // ignore: cast_nullable_to_non_nullable
          : deliver as String?,
      deliverOnly: deliverOnly == const $CopyWithPlaceholder()
          ? _value.deliverOnly
          // ignore: cast_nullable_to_non_nullable
          : deliverOnly as bool?,
      deliverChatId: deliverChatId == const $CopyWithPlaceholder()
          ? _value.deliverChatId
          // ignore: cast_nullable_to_non_nullable
          : deliverChatId as String?,
      secret: secret == const $CopyWithPlaceholder()
          ? _value.secret
          // ignore: cast_nullable_to_non_nullable
          : secret as String?,
    );
  }
}

extension $WebhookCreateCopyWith on WebhookCreate {
  /// Returns a callable class that can be used as follows: `instanceOfWebhookCreate.copyWith(...)` or like so:`instanceOfWebhookCreate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$WebhookCreateCWProxy get copyWith => _$WebhookCreateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

WebhookCreate _$WebhookCreateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'WebhookCreate',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['name']);
    final val = WebhookCreate(
      name: $checkedConvert('name', (v) => v as String),
      description: $checkedConvert('description', (v) => v as String?),
      events: $checkedConvert(
        'events',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      ),
      prompt: $checkedConvert('prompt', (v) => v as String?),
      script: $checkedConvert('script', (v) => v as String?),
      skills: $checkedConvert(
        'skills',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      ),
      deliver: $checkedConvert('deliver', (v) => v as String? ?? 'log'),
      deliverOnly: $checkedConvert('deliver_only', (v) => v as bool? ?? false),
      deliverChatId: $checkedConvert('deliver_chat_id', (v) => v as String?),
      secret: $checkedConvert('secret', (v) => v as String?),
    );
    return val;
  },
  fieldKeyMap: const {
    'deliverOnly': 'deliver_only',
    'deliverChatId': 'deliver_chat_id',
  },
);

Map<String, dynamic> _$WebhookCreateToJson(WebhookCreate instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': ?instance.description,
      'events': ?instance.events,
      'prompt': ?instance.prompt,
      'script': ?instance.script,
      'skills': ?instance.skills,
      'deliver': ?instance.deliver,
      'deliver_only': ?instance.deliverOnly,
      'deliver_chat_id': ?instance.deliverChatId,
      'secret': ?instance.secret,
    };
