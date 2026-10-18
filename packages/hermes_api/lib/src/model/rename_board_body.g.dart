// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'rename_board_body.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$RenameBoardBodyCWProxy {
  RenameBoardBody name(String? name);

  RenameBoardBody description(String? description);

  RenameBoardBody icon(String? icon);

  RenameBoardBody color(String? color);

  RenameBoardBody defaultWorkdir(String? defaultWorkdir);

  RenameBoardBody projectId(String? projectId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `RenameBoardBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// RenameBoardBody(...).copyWith(id: 12, name: "My name")
  /// ```
  RenameBoardBody call({
    String? name,
    String? description,
    String? icon,
    String? color,
    String? defaultWorkdir,
    String? projectId,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfRenameBoardBody.copyWith(...)` or call `instanceOfRenameBoardBody.copyWith.fieldName(value)` for a single field.
class _$RenameBoardBodyCWProxyImpl implements _$RenameBoardBodyCWProxy {
  const _$RenameBoardBodyCWProxyImpl(this._value);

  final RenameBoardBody _value;

  @override
  RenameBoardBody name(String? name) => call(name: name);

  @override
  RenameBoardBody description(String? description) =>
      call(description: description);

  @override
  RenameBoardBody icon(String? icon) => call(icon: icon);

  @override
  RenameBoardBody color(String? color) => call(color: color);

  @override
  RenameBoardBody defaultWorkdir(String? defaultWorkdir) =>
      call(defaultWorkdir: defaultWorkdir);

  @override
  RenameBoardBody projectId(String? projectId) => call(projectId: projectId);

  /// Creates a new instance with the provided field values.
  /// Omitted fields keep their values; explicit `null` clears nullable fields.
  /// The public API rejects `null` for non-nullable fields. To update a single field use `RenameBoardBody(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// RenameBoardBody(...).copyWith(id: 12, name: "My name")
  /// ```
  @override
  RenameBoardBody call({
    Object? name = const $CopyWithPlaceholder(),
    Object? description = const $CopyWithPlaceholder(),
    Object? icon = const $CopyWithPlaceholder(),
    Object? color = const $CopyWithPlaceholder(),
    Object? defaultWorkdir = const $CopyWithPlaceholder(),
    Object? projectId = const $CopyWithPlaceholder(),
  }) {
    return RenameBoardBody(
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
    );
  }
}

extension $RenameBoardBodyCopyWith on RenameBoardBody {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfRenameBoardBody.copyWith(...)` or `instanceOfRenameBoardBody.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$RenameBoardBodyCWProxy get copyWith => _$RenameBoardBodyCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RenameBoardBody _$RenameBoardBodyFromJson(Map<String, dynamic> json) =>
    $checkedCreate(
      'RenameBoardBody',
      json,
      ($checkedConvert) {
        final val = RenameBoardBody(
          name: $checkedConvert('name', (v) => v as String?),
          description: $checkedConvert('description', (v) => v as String?),
          icon: $checkedConvert('icon', (v) => v as String?),
          color: $checkedConvert('color', (v) => v as String?),
          defaultWorkdir: $checkedConvert(
            'default_workdir',
            (v) => v as String?,
          ),
          projectId: $checkedConvert('project_id', (v) => v as String?),
        );
        return val;
      },
      fieldKeyMap: const {
        'defaultWorkdir': 'default_workdir',
        'projectId': 'project_id',
      },
    );

Map<String, dynamic> _$RenameBoardBodyToJson(RenameBoardBody instance) =>
    <String, dynamic>{
      'name': ?instance.name,
      'description': ?instance.description,
      'icon': ?instance.icon,
      'color': ?instance.color,
      'default_workdir': ?instance.defaultWorkdir,
      'project_id': ?instance.projectId,
    };
