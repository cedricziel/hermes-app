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

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CreateBoardBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CreateBoardBody(...).copyWith(id: 12, name: "My name")
  /// ```
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

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCreateBoardBody.copyWith(...)` or call `instanceOfCreateBoardBody.copyWith.fieldName(value)` for a single field.
class _$CreateBoardBodyCWProxyImpl implements _$CreateBoardBodyCWProxy {
  const _$CreateBoardBodyCWProxyImpl(this._value);

  final CreateBoardBody _value;

  @override
  CreateBoardBody slug(String slug) => call(slug: slug);

  @override
  CreateBoardBody name(String? name) => call(name: name);

  @override
  CreateBoardBody description(String? description) =>
      call(description: description);

  @override
  CreateBoardBody icon(String? icon) => call(icon: icon);

  @override
  CreateBoardBody color(String? color) => call(color: color);

  @override
  CreateBoardBody defaultWorkdir(String? defaultWorkdir) =>
      call(defaultWorkdir: defaultWorkdir);

  @override
  CreateBoardBody projectId(String? projectId) => call(projectId: projectId);

  @override
  CreateBoardBody switch_(bool? switch_) => call(switch_: switch_);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `CreateBoardBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CreateBoardBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
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
      slug: slug == const $CopyWithPlaceholder() || slug == null
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
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCreateBoardBody.copyWith(...)` or `instanceOfCreateBoardBody.copyWith.fieldName(...)`.
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
