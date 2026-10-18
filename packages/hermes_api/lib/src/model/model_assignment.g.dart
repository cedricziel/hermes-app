// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'model_assignment.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ModelAssignmentCWProxy {
  ModelAssignment scope(String scope);

  ModelAssignment provider(String provider);

  ModelAssignment model(String model);

  ModelAssignment task(String? task);

  ModelAssignment reasoningEffort(String? reasoningEffort);

  ModelAssignment baseUrl(String? baseUrl);

  ModelAssignment apiKey(String? apiKey);

  ModelAssignment confirmExpensiveModel(bool? confirmExpensiveModel);

  ModelAssignment profile(String? profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ModelAssignment(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ModelAssignment(...).copyWith(id: 12, name: "My name")
  /// ```
  ModelAssignment call({
    String scope,
    String provider,
    String model,
    String? task,
    String? reasoningEffort,
    String? baseUrl,
    String? apiKey,
    bool? confirmExpensiveModel,
    String? profile,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfModelAssignment.copyWith(...)` or call `instanceOfModelAssignment.copyWith.fieldName(value)` for a single field.
class _$ModelAssignmentCWProxyImpl implements _$ModelAssignmentCWProxy {
  const _$ModelAssignmentCWProxyImpl(this._value);

  final ModelAssignment _value;

  @override
  ModelAssignment scope(String scope) => call(scope: scope);

  @override
  ModelAssignment provider(String provider) => call(provider: provider);

  @override
  ModelAssignment model(String model) => call(model: model);

  @override
  ModelAssignment task(String? task) => call(task: task);

  @override
  ModelAssignment reasoningEffort(String? reasoningEffort) =>
      call(reasoningEffort: reasoningEffort);

  @override
  ModelAssignment baseUrl(String? baseUrl) => call(baseUrl: baseUrl);

  @override
  ModelAssignment apiKey(String? apiKey) => call(apiKey: apiKey);

  @override
  ModelAssignment confirmExpensiveModel(bool? confirmExpensiveModel) =>
      call(confirmExpensiveModel: confirmExpensiveModel);

  @override
  ModelAssignment profile(String? profile) => call(profile: profile);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ModelAssignment(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ModelAssignment(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ModelAssignment call({
    Object? scope = const $CopyWithPlaceholder(),
    Object? provider = const $CopyWithPlaceholder(),
    Object? model = const $CopyWithPlaceholder(),
    Object? task = const $CopyWithPlaceholder(),
    Object? reasoningEffort = const $CopyWithPlaceholder(),
    Object? baseUrl = const $CopyWithPlaceholder(),
    Object? apiKey = const $CopyWithPlaceholder(),
    Object? confirmExpensiveModel = const $CopyWithPlaceholder(),
    Object? profile = const $CopyWithPlaceholder(),
  }) {
    return ModelAssignment(
      scope: scope == const $CopyWithPlaceholder() || scope == null
          ? _value.scope
          // ignore: cast_nullable_to_non_nullable
          : scope as String,
      provider: provider == const $CopyWithPlaceholder() || provider == null
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String,
      model: model == const $CopyWithPlaceholder() || model == null
          ? _value.model
          // ignore: cast_nullable_to_non_nullable
          : model as String,
      task: task == const $CopyWithPlaceholder()
          ? _value.task
          // ignore: cast_nullable_to_non_nullable
          : task as String?,
      reasoningEffort: reasoningEffort == const $CopyWithPlaceholder()
          ? _value.reasoningEffort
          // ignore: cast_nullable_to_non_nullable
          : reasoningEffort as String?,
      baseUrl: baseUrl == const $CopyWithPlaceholder()
          ? _value.baseUrl
          // ignore: cast_nullable_to_non_nullable
          : baseUrl as String?,
      apiKey: apiKey == const $CopyWithPlaceholder()
          ? _value.apiKey
          // ignore: cast_nullable_to_non_nullable
          : apiKey as String?,
      confirmExpensiveModel:
          confirmExpensiveModel == const $CopyWithPlaceholder()
          ? _value.confirmExpensiveModel
          // ignore: cast_nullable_to_non_nullable
          : confirmExpensiveModel as bool?,
      profile: profile == const $CopyWithPlaceholder()
          ? _value.profile
          // ignore: cast_nullable_to_non_nullable
          : profile as String?,
    );
  }
}

extension $ModelAssignmentCopyWith on ModelAssignment {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfModelAssignment.copyWith(...)` or `instanceOfModelAssignment.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ModelAssignmentCWProxy get copyWith => _$ModelAssignmentCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ModelAssignment _$ModelAssignmentFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ModelAssignment',
      json,
      ($checkedConvert) {
        $checkKeys(json, requiredKeys: const ['scope', 'provider', 'model']);
        final val = ModelAssignment(
          scope: $checkedConvert('scope', (v) => v as String),
          provider: $checkedConvert('provider', (v) => v as String),
          model: $checkedConvert('model', (v) => v as String),
          task: $checkedConvert('task', (v) => v as String? ?? ''),
          reasoningEffort: $checkedConvert(
            'reasoning_effort',
            (v) => v as String?,
          ),
          baseUrl: $checkedConvert('base_url', (v) => v as String? ?? ''),
          apiKey: $checkedConvert('api_key', (v) => v as String? ?? ''),
          confirmExpensiveModel: $checkedConvert(
            'confirm_expensive_model',
            (v) => v as bool? ?? false,
          ),
          profile: $checkedConvert('profile', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'reasoningEffort': 'reasoning_effort',
        'baseUrl': 'base_url',
        'apiKey': 'api_key',
        'confirmExpensiveModel': 'confirm_expensive_model',
      },
    );

Map<String, dynamic> _$ModelAssignmentToJson(ModelAssignment instance) =>
    <String, dynamic>{
      'scope': instance.scope,
      'provider': instance.provider,
      'model': instance.model,
      'task': ?instance.task,
      'reasoning_effort': ?instance.reasoningEffort,
      'base_url': ?instance.baseUrl,
      'api_key': ?instance.apiKey,
      'confirm_expensive_model': ?instance.confirmExpensiveModel,
      'profile': ?instance.profile,
    };
