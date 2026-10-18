// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cron_job_create.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CronJobCreateCWProxy {
  CronJobCreate paused(bool? paused);

  CronJobCreate pausedReason(String? pausedReason);

  CronJobCreate prompt(String? prompt);

  CronJobCreate schedule(String schedule);

  CronJobCreate name(String? name);

  CronJobCreate deliver(String? deliver);

  CronJobCreate repeat(Object? repeat);

  CronJobCreate skills(List<String>? skills);

  CronJobCreate model(String? model);

  CronJobCreate provider(String? provider);

  CronJobCreate baseUrl(String? baseUrl);

  CronJobCreate script(String? script);

  CronJobCreate contextFrom(Object? contextFrom);

  CronJobCreate enabledToolsets(List<String>? enabledToolsets);

  CronJobCreate workdir(String? workdir);

  CronJobCreate noAgent(bool? noAgent);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CronJobCreate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CronJobCreate(...).copyWith(id: 12, name: "My name")
  /// ```
  CronJobCreate call({
    bool? paused,
    String? pausedReason,
    String? prompt,
    String schedule,
    String? name,
    String? deliver,
    Object? repeat,
    List<String>? skills,
    String? model,
    String? provider,
    String? baseUrl,
    String? script,
    Object? contextFrom,
    List<String>? enabledToolsets,
    String? workdir,
    bool? noAgent,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCronJobCreate.copyWith(...)` or call `instanceOfCronJobCreate.copyWith.fieldName(value)` for a single field.
class _$CronJobCreateCWProxyImpl implements _$CronJobCreateCWProxy {
  const _$CronJobCreateCWProxyImpl(this._value);

  final CronJobCreate _value;

  @override
  CronJobCreate paused(bool? paused) => call(paused: paused);

  @override
  CronJobCreate pausedReason(String? pausedReason) =>
      call(pausedReason: pausedReason);

  @override
  CronJobCreate prompt(String? prompt) => call(prompt: prompt);

  @override
  CronJobCreate schedule(String schedule) => call(schedule: schedule);

  @override
  CronJobCreate name(String? name) => call(name: name);

  @override
  CronJobCreate deliver(String? deliver) => call(deliver: deliver);

  @override
  CronJobCreate repeat(Object? repeat) => call(repeat: repeat);

  @override
  CronJobCreate skills(List<String>? skills) => call(skills: skills);

  @override
  CronJobCreate model(String? model) => call(model: model);

  @override
  CronJobCreate provider(String? provider) => call(provider: provider);

  @override
  CronJobCreate baseUrl(String? baseUrl) => call(baseUrl: baseUrl);

  @override
  CronJobCreate script(String? script) => call(script: script);

  @override
  CronJobCreate contextFrom(Object? contextFrom) =>
      call(contextFrom: contextFrom);

  @override
  CronJobCreate enabledToolsets(List<String>? enabledToolsets) =>
      call(enabledToolsets: enabledToolsets);

  @override
  CronJobCreate workdir(String? workdir) => call(workdir: workdir);

  @override
  CronJobCreate noAgent(bool? noAgent) => call(noAgent: noAgent);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CronJobCreate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CronJobCreate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  CronJobCreate call({
    Object? paused = const $CopyWithPlaceholder(),
    Object? pausedReason = const $CopyWithPlaceholder(),
    Object? prompt = const $CopyWithPlaceholder(),
    Object? schedule = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? deliver = const $CopyWithPlaceholder(),
    Object? repeat = const $CopyWithPlaceholder(),
    Object? skills = const $CopyWithPlaceholder(),
    Object? model = const $CopyWithPlaceholder(),
    Object? provider = const $CopyWithPlaceholder(),
    Object? baseUrl = const $CopyWithPlaceholder(),
    Object? script = const $CopyWithPlaceholder(),
    Object? contextFrom = const $CopyWithPlaceholder(),
    Object? enabledToolsets = const $CopyWithPlaceholder(),
    Object? workdir = const $CopyWithPlaceholder(),
    Object? noAgent = const $CopyWithPlaceholder(),
  }) {
    return CronJobCreate(
      paused: paused == const $CopyWithPlaceholder()
          ? _value.paused
          // ignore: cast_nullable_to_non_nullable
          : paused as bool?,
      pausedReason: pausedReason == const $CopyWithPlaceholder()
          ? _value.pausedReason
          // ignore: cast_nullable_to_non_nullable
          : pausedReason as String?,
      prompt: prompt == const $CopyWithPlaceholder()
          ? _value.prompt
          // ignore: cast_nullable_to_non_nullable
          : prompt as String?,
      schedule: schedule == const $CopyWithPlaceholder() || schedule == null
          ? _value.schedule
          // ignore: cast_nullable_to_non_nullable
          : schedule as String,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String?,
      deliver: deliver == const $CopyWithPlaceholder()
          ? _value.deliver
          // ignore: cast_nullable_to_non_nullable
          : deliver as String?,
      repeat: repeat == const $CopyWithPlaceholder()
          ? _value.repeat
          // ignore: cast_nullable_to_non_nullable
          : repeat as Object?,
      skills: skills == const $CopyWithPlaceholder()
          ? _value.skills
          // ignore: cast_nullable_to_non_nullable
          : skills as List<String>?,
      model: model == const $CopyWithPlaceholder()
          ? _value.model
          // ignore: cast_nullable_to_non_nullable
          : model as String?,
      provider: provider == const $CopyWithPlaceholder()
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String?,
      baseUrl: baseUrl == const $CopyWithPlaceholder()
          ? _value.baseUrl
          // ignore: cast_nullable_to_non_nullable
          : baseUrl as String?,
      script: script == const $CopyWithPlaceholder()
          ? _value.script
          // ignore: cast_nullable_to_non_nullable
          : script as String?,
      contextFrom: contextFrom == const $CopyWithPlaceholder()
          ? _value.contextFrom
          // ignore: cast_nullable_to_non_nullable
          : contextFrom as Object?,
      enabledToolsets: enabledToolsets == const $CopyWithPlaceholder()
          ? _value.enabledToolsets
          // ignore: cast_nullable_to_non_nullable
          : enabledToolsets as List<String>?,
      workdir: workdir == const $CopyWithPlaceholder()
          ? _value.workdir
          // ignore: cast_nullable_to_non_nullable
          : workdir as String?,
      noAgent: noAgent == const $CopyWithPlaceholder()
          ? _value.noAgent
          // ignore: cast_nullable_to_non_nullable
          : noAgent as bool?,
    );
  }
}

extension $CronJobCreateCopyWith on CronJobCreate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCronJobCreate.copyWith(...)` or `instanceOfCronJobCreate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CronJobCreateCWProxy get copyWith => _$CronJobCreateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CronJobCreate _$CronJobCreateFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CronJobCreate',
      json,
      ($checkedConvert) {
        $checkKeys(json, requiredKeys: const ['schedule']);
        final val = CronJobCreate(
          paused: $checkedConvert('paused', (v) => v as bool? ?? false),
          pausedReason: $checkedConvert('paused_reason', (v) => v as String?),
          prompt: $checkedConvert('prompt', (v) => v as String? ?? ''),
          schedule: $checkedConvert('schedule', (v) => v as String),
          name: $checkedConvert('name', (v) => v as String? ?? ''),
          deliver: $checkedConvert('deliver', (v) => v as String? ?? 'local'),
          repeat: $checkedConvert('repeat', (v) => v),
          skills: $checkedConvert(
            'skills',
            (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
          ),
          model: $checkedConvert('model', (v) => v as String?),
          provider: $checkedConvert('provider', (v) => v as String?),
          baseUrl: $checkedConvert('base_url', (v) => v as String?),
          script: $checkedConvert('script', (v) => v as String?),
          contextFrom: $checkedConvert('context_from', (v) => v),
          enabledToolsets: $checkedConvert(
            'enabled_toolsets',
            (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
          ),
          workdir: $checkedConvert('workdir', (v) => v as String?),
          noAgent: $checkedConvert('no_agent', (v) => v as bool? ?? false),
        );
        return val;
      },
      fieldKeyMap: const {
        'pausedReason': 'paused_reason',
        'baseUrl': 'base_url',
        'contextFrom': 'context_from',
        'enabledToolsets': 'enabled_toolsets',
        'noAgent': 'no_agent',
      },
    );

Map<String, dynamic> _$CronJobCreateToJson(CronJobCreate instance) =>
    <String, dynamic>{
      'paused': ?instance.paused,
      'paused_reason': ?instance.pausedReason,
      'prompt': ?instance.prompt,
      'schedule': instance.schedule,
      'name': ?instance.name,
      'deliver': ?instance.deliver,
      'repeat': ?instance.repeat,
      'skills': ?instance.skills,
      'model': ?instance.model,
      'provider': ?instance.provider,
      'base_url': ?instance.baseUrl,
      'script': ?instance.script,
      'context_from': ?instance.contextFrom,
      'enabled_toolsets': ?instance.enabledToolsets,
      'workdir': ?instance.workdir,
      'no_agent': ?instance.noAgent,
    };
