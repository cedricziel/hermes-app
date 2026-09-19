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

  CustomEndpointUpdate contextLength(int? contextLength);

  CustomEndpointUpdate discoverModels(bool? discoverModels);

  CustomEndpointUpdate makeDefault(bool? makeDefault);

  CustomEndpointUpdate models(List<String>? models);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CustomEndpointUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CustomEndpointUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  CustomEndpointUpdate call({
    String? id,
    String name,
    String baseUrl,
    String model,
    String? apiKey,
    int? contextLength,
    bool? discoverModels,
    bool? makeDefault,
    List<String>? models,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCustomEndpointUpdate.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCustomEndpointUpdate.copyWith.fieldName(...)`
class _$CustomEndpointUpdateCWProxyImpl
    implements _$CustomEndpointUpdateCWProxy {
  const _$CustomEndpointUpdateCWProxyImpl(this._value);

  final CustomEndpointUpdate _value;

  @override
  CustomEndpointUpdate id(String? id) => this(id: id);

  @override
  CustomEndpointUpdate name(String name) => this(name: name);

  @override
  CustomEndpointUpdate baseUrl(String baseUrl) => this(baseUrl: baseUrl);

  @override
  CustomEndpointUpdate model(String model) => this(model: model);

  @override
  CustomEndpointUpdate apiKey(String? apiKey) => this(apiKey: apiKey);

  @override
  CustomEndpointUpdate contextLength(int? contextLength) =>
      this(contextLength: contextLength);

  @override
  CustomEndpointUpdate discoverModels(bool? discoverModels) =>
      this(discoverModels: discoverModels);

  @override
  CustomEndpointUpdate makeDefault(bool? makeDefault) =>
      this(makeDefault: makeDefault);

  @override
  CustomEndpointUpdate models(List<String>? models) => this(models: models);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CustomEndpointUpdate(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CustomEndpointUpdate(...).copyWith(id: 12, name: "My name")
  /// ````
  CustomEndpointUpdate call({
    Object? id = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? baseUrl = const $CopyWithPlaceholder(),
    Object? model = const $CopyWithPlaceholder(),
    Object? apiKey = const $CopyWithPlaceholder(),
    Object? contextLength = const $CopyWithPlaceholder(),
    Object? discoverModels = const $CopyWithPlaceholder(),
    Object? makeDefault = const $CopyWithPlaceholder(),
    Object? models = const $CopyWithPlaceholder(),
  }) {
    return CustomEndpointUpdate(
      id: id == const $CopyWithPlaceholder()
          ? _value.id
          // ignore: cast_nullable_to_non_nullable
          : id as String?,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      baseUrl: baseUrl == const $CopyWithPlaceholder()
          ? _value.baseUrl
          // ignore: cast_nullable_to_non_nullable
          : baseUrl as String,
      model: model == const $CopyWithPlaceholder()
          ? _value.model
          // ignore: cast_nullable_to_non_nullable
          : model as String,
      apiKey: apiKey == const $CopyWithPlaceholder()
          ? _value.apiKey
          // ignore: cast_nullable_to_non_nullable
          : apiKey as String?,
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
    );
  }
}

extension $CustomEndpointUpdateCopyWith on CustomEndpointUpdate {
  /// Returns a callable class that can be used as follows: `instanceOfCustomEndpointUpdate.copyWith(...)` or like so:`instanceOfCustomEndpointUpdate.copyWith.fieldName(...)`.
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
    );
    return val;
  },
  fieldKeyMap: const {
    'baseUrl': 'base_url',
    'apiKey': 'api_key',
    'contextLength': 'context_length',
    'discoverModels': 'discover_models',
    'makeDefault': 'make_default',
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
  'context_length': ?instance.contextLength,
  'discover_models': ?instance.discoverModels,
  'make_default': ?instance.makeDefault,
  'models': ?instance.models,
};
