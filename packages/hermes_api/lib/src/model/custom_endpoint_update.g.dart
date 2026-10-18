// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'custom_endpoint_update.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CustomEndpointUpdateCWProxy {
  CustomEndpointUpdate id(String? id);

  CustomEndpointUpdate name(String name);

  CustomEndpointUpdate baseUrl(String baseUrl);

  CustomEndpointUpdate model(String model);

  CustomEndpointUpdate apiKey(String? apiKey);

  CustomEndpointUpdate apiMode(String? apiMode);

  CustomEndpointUpdate contextLength(int? contextLength);

  CustomEndpointUpdate discoverModels(bool? discoverModels);

  CustomEndpointUpdate makeDefault(bool? makeDefault);

  CustomEndpointUpdate models(List<String>? models);

  CustomEndpointUpdate modelDetails(
    List<CustomEndpointModelDetail>? modelDetails,
  );

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CustomEndpointUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CustomEndpointUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  CustomEndpointUpdate call({
    String? id,
    String name,
    String baseUrl,
    String model,
    String? apiKey,
    String? apiMode,
    int? contextLength,
    bool? discoverModels,
    bool? makeDefault,
    List<String>? models,
    List<CustomEndpointModelDetail>? modelDetails,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCustomEndpointUpdate.copyWith(...)` or call `instanceOfCustomEndpointUpdate.copyWith.fieldName(value)` for a single field.
class _$CustomEndpointUpdateCWProxyImpl
    implements _$CustomEndpointUpdateCWProxy {
  const _$CustomEndpointUpdateCWProxyImpl(this._value);

  final CustomEndpointUpdate _value;

  @override
  CustomEndpointUpdate id(String? id) => call(id: id);

  @override
  CustomEndpointUpdate name(String name) => call(name: name);

  @override
  CustomEndpointUpdate baseUrl(String baseUrl) => call(baseUrl: baseUrl);

  @override
  CustomEndpointUpdate model(String model) => call(model: model);

  @override
  CustomEndpointUpdate apiKey(String? apiKey) => call(apiKey: apiKey);

  @override
  CustomEndpointUpdate apiMode(String? apiMode) => call(apiMode: apiMode);

  @override
  CustomEndpointUpdate contextLength(int? contextLength) =>
      call(contextLength: contextLength);

  @override
  CustomEndpointUpdate discoverModels(bool? discoverModels) =>
      call(discoverModels: discoverModels);

  @override
  CustomEndpointUpdate makeDefault(bool? makeDefault) =>
      call(makeDefault: makeDefault);

  @override
  CustomEndpointUpdate models(List<String>? models) => call(models: models);

  @override
  CustomEndpointUpdate modelDetails(
    List<CustomEndpointModelDetail>? modelDetails,
  ) => call(modelDetails: modelDetails);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CustomEndpointUpdate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CustomEndpointUpdate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  CustomEndpointUpdate call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? baseUrl = const $CopyWithPlaceholder(),
    Object? model = const $CopyWithPlaceholder(),
    Object? apiKey = const $CopyWithPlaceholder(),
    Object? apiMode = const $CopyWithPlaceholder(),
    Object? contextLength = const $CopyWithPlaceholder(),
    Object? discoverModels = const $CopyWithPlaceholder(),
    Object? makeDefault = const $CopyWithPlaceholder(),
    Object? models = const $CopyWithPlaceholder(),
    Object? modelDetails = const $CopyWithPlaceholder(),
  }) {
    return CustomEndpointUpdate(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String?,
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      baseUrl: baseUrl == const $CopyWithPlaceholder() || baseUrl == null
          ? _value.baseUrl
          // ignore: cast_nullable_to_non_nullable
          : baseUrl as String,
      model: model == const $CopyWithPlaceholder() || model == null
          ? _value.model
          // ignore: cast_nullable_to_non_nullable
          : model as String,
      apiKey: apiKey == const $CopyWithPlaceholder()
          ? _value.apiKey
          // ignore: cast_nullable_to_non_nullable
          : apiKey as String?,
      apiMode: apiMode == const $CopyWithPlaceholder()
          ? _value.apiMode
          // ignore: cast_nullable_to_non_nullable
          : apiMode as String?,
      contextLength: contextLength == const $CopyWithPlaceholder()
          ? _value.contextLength
          // ignore: cast_nullable_to_non_nullable
          : contextLength as int?,
      discoverModels: discoverModels == const $CopyWithPlaceholder()
          ? _value.discoverModels
          // ignore: cast_nullable_to_non_nullable
          : discoverModels as bool?,
      makeDefault: makeDefault == const $CopyWithPlaceholder()
          ? _value.makeDefault
          // ignore: cast_nullable_to_non_nullable
          : makeDefault as bool?,
      models: models == const $CopyWithPlaceholder()
          ? _value.models
          // ignore: cast_nullable_to_non_nullable
          : models as List<String>?,
      modelDetails: modelDetails == const $CopyWithPlaceholder()
          ? _value.modelDetails
          // ignore: cast_nullable_to_non_nullable
          : modelDetails as List<CustomEndpointModelDetail>?,
    );
  }
}

extension $CustomEndpointUpdateCopyWith on CustomEndpointUpdate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCustomEndpointUpdate.copyWith(...)` or `instanceOfCustomEndpointUpdate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CustomEndpointUpdateCWProxy get copyWith =>
      _$CustomEndpointUpdateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CustomEndpointUpdate _$CustomEndpointUpdateFromJson(
  Map<String, dynamic> json,
) => $checkedCreate(
  'CustomEndpointUpdate',
  json,
  ($checkedConvert) {
    $checkKeys(json, requiredKeys: const ['name', 'base_url', 'model']);
    final val = CustomEndpointUpdate(
      id: $checkedConvert('id', (v) => v as String? ?? ''),
      name: $checkedConvert('name', (v) => v as String),
      baseUrl: $checkedConvert('base_url', (v) => v as String),
      model: $checkedConvert('model', (v) => v as String),
      apiKey: $checkedConvert('api_key', (v) => v as String?),
      apiMode: $checkedConvert('api_mode', (v) => v as String?),
      contextLength: $checkedConvert(
        'context_length',
        (v) => (v as num?)?.toInt(),
      ),
      discoverModels: $checkedConvert(
        'discover_models',
        (v) => v as bool? ?? true,
      ),
      makeDefault: $checkedConvert('make_default', (v) => v as bool? ?? false),
      models: $checkedConvert(
        'models',
        (v) => (v as List<dynamic>?)?.map((e) => e as String).toList(),
      ),
      modelDetails: $checkedConvert(
        'model_details',
        (v) => (v as List<dynamic>?)
            ?.map(
              (e) =>
                  CustomEndpointModelDetail.fromJson(e as Map<String, dynamic>),
            )
            .toList(),
      ),
    );
    return val;
  },
  fieldKeyMap: const {
    'baseUrl': 'base_url',
    'apiKey': 'api_key',
    'apiMode': 'api_mode',
    'contextLength': 'context_length',
    'discoverModels': 'discover_models',
    'makeDefault': 'make_default',
    'modelDetails': 'model_details',
  },
);

Map<String, dynamic> _$CustomEndpointUpdateToJson(
  CustomEndpointUpdate instance,
) => <String, dynamic>{
  'id': ?instance.id,
  'name': instance.name,
  'base_url': instance.baseUrl,
  'model': instance.model,
  'api_key': ?instance.apiKey,
  'api_mode': ?instance.apiMode,
  'context_length': ?instance.contextLength,
  'discover_models': ?instance.discoverModels,
  'make_default': ?instance.makeDefault,
  'models': ?instance.models,
  'model_details': ?instance.modelDetails?.map((e) => e.toJson()).toList(),
};
