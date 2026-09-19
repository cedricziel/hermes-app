// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'create_board_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CreateBoardBodyCWProxy {
  CreateBoardBody slug(String slug);

  CreateBoardBody name(String? name);

  CreateBoardBody description(String? description);

  CreateBoardBody icon(String? icon);

  CreateBoardBody color(String? color);

  CreateBoardBody defaultWorkdir(String? defaultWorkdir);

  CreateBoardBody projectId(String? projectId);

  CreateBoardBody switch_(bool? switch_);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateBoardBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateBoardBody(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateBoardBody call({
    String slug,
    String? name,
    String? description,
    String? icon,
    String? color,
    String? defaultWorkdir,
    String? projectId,
    bool? switch_,
  });
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfCreateBoardBody.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfCreateBoardBody.copyWith.fieldName(...)`
class _$CreateBoardBodyCWProxyImpl implements _$CreateBoardBodyCWProxy {
  const _$CreateBoardBodyCWProxyImpl(this._value);

  final CreateBoardBody _value;

  @override
  CreateBoardBody slug(String slug) => this(slug: slug);

  @override
  CreateBoardBody name(String? name) => this(name: name);

  @override
  CreateBoardBody description(String? description) =>
      this(description: description);

  @override
  CreateBoardBody icon(String? icon) => this(icon: icon);

  @override
  CreateBoardBody color(String? color) => this(color: color);

  @override
  CreateBoardBody defaultWorkdir(String? defaultWorkdir) =>
      this(defaultWorkdir: defaultWorkdir);

  @override
  CreateBoardBody projectId(String? projectId) => this(projectId: projectId);

  @override
  CreateBoardBody switch_(bool? switch_) => this(switch_: switch_);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `CreateBoardBody(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// CreateBoardBody(...).copyWith(id: 12, name: "My name")
  /// ````
  CreateBoardBody call({
    Object? slug = const $CopyWithPlaceholder(),
    Object? name = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? icon = const $CopyWithPlaceholder(),
    Object? color = const $CopyWithPlaceholder(),
    Object? defaultWorkdir = const $CopyWithPlaceholder(),
    Object? projectId = const $CopyWithPlaceholder(),
    Object? switch_ = const $CopyWithPlaceholder(),
  }) {
    return CreateBoardBody(
      slug: slug == const $CopyWithPlaceholder()
          ? _value.slug
          // ignore: cast_nullable_to_non_nullable
          : slug as String,
      name: name == const $CopyWithPlaceholder()
          ? _value.name
          // ignore: cast_nullable_to_non_nullable
          : name as String?,
      description: description == const $CopyWithPlaceholder()
          ? _value.description
          // ignore: cast_nullable_to_non_nullable
          : description as String?,
      icon: icon == const $CopyWithPlaceholder()
          ? _value.icon
          // ignore: cast_nullable_to_non_nullable
          : icon as String?,
      color: color == const $CopyWithPlaceholder()
          ? _value.color
          // ignore: cast_nullable_to_non_nullable
          : color as String?,
      defaultWorkdir: defaultWorkdir == const $CopyWithPlaceholder()
          ? _value.defaultWorkdir
          // ignore: cast_nullable_to_non_nullable
          : defaultWorkdir as String?,
      projectId: projectId == const $CopyWithPlaceholder()
          ? _value.projectId
          // ignore: cast_nullable_to_non_nullable
          : projectId as String?,
      switch_: switch_ == const $CopyWithPlaceholder()
          ? _value.switch_
          // ignore: cast_nullable_to_non_nullable
          : switch_ as bool?,
    );
  }
}

extension $CreateBoardBodyCopyWith on CreateBoardBody {
  /// Returns a callable class that can be used as follows: `instanceOfCreateBoardBody.copyWith(...)` or like so:`instanceOfCreateBoardBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CreateBoardBodyCWProxy get copyWith => _$CreateBoardBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CreateBoardBody _$CreateBoardBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'CreateBoardBody',
      json,
      ($checkedConvert) {
        $checkKeys(json, requiredKeys: const ['slug']);
        final val = CreateBoardBody(
          slug: $checkedConvert('slug', (v) => v as String),
          name: $checkedConvert('name', (v) => v as String?),
          description: $checkedConvert('description', (v) => v as String?),
          icon: $checkedConvert('icon', (v) => v as String?),
          color: $checkedConvert('color', (v) => v as String?),
          defaultWorkdir: $checkedConvert(
            'default_workdir',
            (v) => v as String?,
          ),
          projectId: $checkedConvert('project_id', (v) => v as String?),
          switch_: $checkedConvert('switch', (v) => v as bool? ?? false),
        );
        return val;
      },
      fieldKeyMap: const {
        'defaultWorkdir': 'default_workdir',
        'projectId': 'project_id',
        'switch_': 'switch',
      },
    );

Map<String, dynamic> _$CreateBoardBodyToJson(CreateBoardBody instance) =>
    <String, dynamic>{
      'slug': instance.slug,
      'name': ?instance.name,
      'description': ?instance.description,
      'icon': ?instance.icon,
      'color': ?instance.color,
      'default_workdir': ?instance.defaultWorkdir,
      'project_id': ?instance.projectId,
      'switch': ?instance.switch_,
    };
