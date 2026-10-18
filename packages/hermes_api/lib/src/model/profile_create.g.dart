// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_create.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$ProfileCreateCWProxy {
  ProfileCreate name(String name);

  ProfileCreate cloneFrom(String? cloneFrom);

  ProfileCreate cloneFromDefault(bool? cloneFromDefault);

  ProfileCreate cloneAll(bool? cloneAll);

  ProfileCreate cloneChannels(bool? cloneChannels);

  ProfileCreate noSkills(bool? noSkills);

  ProfileCreate description(String? description);

  ProfileCreate provider(String? provider);

  ProfileCreate model(String? model);

  ProfileCreate mcpServers(List<MCPServerCreate>? mcpServers);

  ProfileCreate keepSkills(List<String>? keepSkills);

  ProfileCreate hubSkills(List<String>? hubSkills);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileCreate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileCreate(...).copyWith(id: 12, name: "My name")
  /// ```
  ProfileCreate call({
    String name,
    String? cloneFrom,
    bool? cloneFromDefault,
    bool? cloneAll,
    bool? cloneChannels,
    bool? noSkills,
    String? description,
    String? provider,
    String? model,
    List<MCPServerCreate>? mcpServers,
    List<String>? keepSkills,
    List<String>? hubSkills,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfProfileCreate.copyWith(...)` or call `instanceOfProfileCreate.copyWith.fieldName(value)` for a single field.
class _$ProfileCreateCWProxyImpl implements _$ProfileCreateCWProxy {
  const _$ProfileCreateCWProxyImpl(this._value);

  final ProfileCreate _value;

  @override
  ProfileCreate name(String name) => call(name: name);

  @override
  ProfileCreate cloneFrom(String? cloneFrom) => call(cloneFrom: cloneFrom);

  @override
  ProfileCreate cloneFromDefault(bool? cloneFromDefault) =>
      call(cloneFromDefault: cloneFromDefault);

  @override
  ProfileCreate cloneAll(bool? cloneAll) => call(cloneAll: cloneAll);

  @override
  ProfileCreate cloneChannels(bool? cloneChannels) =>
      call(cloneChannels: cloneChannels);

  @override
  ProfileCreate noSkills(bool? noSkills) => call(noSkills: noSkills);

  @override
  ProfileCreate description(String? description) =>
      call(description: description);

  @override
  ProfileCreate provider(String? provider) => call(provider: provider);

  @override
  ProfileCreate model(String? model) => call(model: model);

  @override
  ProfileCreate mcpServers(List<MCPServerCreate>? mcpServers) =>
      call(mcpServers: mcpServers);

  @override
  ProfileCreate keepSkills(List<String>? keepSkills) =>
      call(keepSkills: keepSkills);

  @override
  ProfileCreate hubSkills(List<String>? hubSkills) =>
      call(hubSkills: hubSkills);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `ProfileCreate(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// ProfileCreate(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  ProfileCreate call({
    Object? name = const $CopyWithPlaceholder(),
    Object? cloneFrom = const $CopyWithPlaceholder(),
    Object? cloneFromDefault = const $CopyWithPlaceholder(),
    Object? cloneAll = const $CopyWithPlaceholder(),
    Object? cloneChannels = const $CopyWithPlaceholder(),
    Object? noSkills = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? provider = const $CopyWithPlaceholder(),
    Object? model = const $CopyWithPlaceholder(),
    Object? mcpServers = const $CopyWithPlaceholder(),
    Object? keepSkills = const $CopyWithPlaceholder(),
    Object? hubSkills = const $CopyWithPlaceholder(),
  }) {
    return ProfileCreate(
      name: name == const $CopyWithPlaceholder() || name == null
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String,
      cloneFrom: cloneFrom == const $CopyWithPlaceholder()
          ? _value.cloneFrom
          // ignore: cast_nullable_to_non_nullable
          : cloneFrom as String?,
      cloneFromDefault: cloneFromDefault == const $CopyWithPlaceholder()
          ? _value.cloneFromDefault
          // ignore: cast_nullable_to_non_nullable
          : cloneFromDefault as bool?,
      cloneAll: cloneAll == const $CopyWithPlaceholder()
          ? _value.cloneAll
          // ignore: cast_nullable_to_non_nullable
          : cloneAll as bool?,
      cloneChannels: cloneChannels == const $CopyWithPlaceholder()
          ? _value.cloneChannels
          // ignore: cast_nullable_to_non_nullable
          : cloneChannels as bool?,
      noSkills: noSkills == const $CopyWithPlaceholder()
          ? _value.noSkills
          // ignore: cast_nullable_to_non_nullable
          : noSkills as bool?,
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String?,
      provider: provider == const $CopyWithPlaceholder()
          ? _value.provider
          // ignore: cast_nullable_to_non_nullable
          : provider as String?,
      model: model == const $CopyWithPlaceholder()
          ? _value.model
          // ignore: cast_nullable_to_non_nullable
          : model as String?,
      mcpServers: mcpServers == const $CopyWithPlaceholder()
          ? _value.mcpServers
          // ignore: cast_nullable_to_non_nullable
          : mcpServers as List<MCPServerCreate>?,
      keepSkills: keepSkills == const $CopyWithPlaceholder()
          ? _value.keepSkills
          // ignore: cast_nullable_to_non_nullable
          : keepSkills as List<String>?,
      hubSkills: hubSkills == const $CopyWithPlaceholder()
          ? _value.hubSkills
          // ignore: cast_nullable_to_non_nullable
          : hubSkills as List<String>?,
    );
  }
}

extension $ProfileCreateCopyWith on ProfileCreate {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfProfileCreate.copyWith(...)` or `instanceOfProfileCreate.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$ProfileCreateCWProxy get copyWith => _$ProfileCreateCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ProfileCreate _$ProfileCreateFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'ProfileCreate',
      json,
      ($checkedConvert) {
        $checkKeys(json, requiredKeys: const ['name']);
        final val = ProfileCreate(
          name: $checkedConvert('name', (v) => v as String),
          cloneFrom: $checkedConvert('clone_from', (v) => v as String?),
          cloneFromDefault: $checkedConvert(
            'clone_from_default',
            (v) => v as bool? ?? false,
          ),
          cloneAll: $checkedConvert('clone_all', (v) => v as bool? ?? false),
          cloneChannels: $checkedConvert(
            'clone_channels',
            (v) => v as bool? ?? false,
          ),
          noSkills: $checkedConvert('no_skills', (v) => v as bool? ?? false),
          description: $checkedConvert('description', (v) => v as String?),
          provider: $checkedConvert('provider', (v) => v as String?),
          model: $checkedConvert('model', (v) => v as String?),
          mcpServers: $checkedConvert(
            'mcp_servers',
            (v) =>
                (v as List<dynamic>?)
                    ?.map(
                      (e) =>
                          MCPServerCreate.fromJson(e as Map<String, dynamic>),
                    )
                    .toList() ??
                [],
          ),
          keepSkills: $checkedConvert(
            'keep_skills',
            (v) =>
                (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
          ),
          hubSkills: $checkedConvert(
            'hub_skills',
            (v) =>
                (v as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
          ),
        );
        return val;
      },
      fieldKeyMap: const {
        'cloneFrom': 'clone_from',
        'cloneFromDefault': 'clone_from_default',
        'cloneAll': 'clone_all',
        'cloneChannels': 'clone_channels',
        'noSkills': 'no_skills',
        'mcpServers': 'mcp_servers',
        'keepSkills': 'keep_skills',
        'hubSkills': 'hub_skills',
      },
    );

Map<String, dynamic> _$ProfileCreateToJson(ProfileCreate instance) =>
    <String, dynamic>{
      'name': instance.name,
      'clone_from': ?instance.cloneFrom,
      'clone_from_default': ?instance.cloneFromDefault,
      'clone_all': ?instance.cloneAll,
      'clone_channels': ?instance.cloneChannels,
      'no_skills': ?instance.noSkills,
      'description': ?instance.description,
      'provider': ?instance.provider,
      'model': ?instance.model,
      'mcp_servers': ?instance.mcpServers?.map((e) => e.toJson()).toList(),
      'keep_skills': ?instance.keepSkills,
      'hub_skills': ?instance.hubSkills,
    };
